// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {Events} from "../libraries/Events.sol";

/// @title TWAPOracle
/// @notice Time-Weighted Average Price oracle with heartbeat enforcement,
///         staleness checks, and multi-observation ring buffer.
///
///         Designed as a secure oracle adapter for the OnLoan protocol.
///         Can be used alongside or as a replacement for the basic PriceOracle.
///
/// Features:
///   - Ring buffer storing the last N price observations per token
///   - Configurable TWAP window (e.g., 30 minutes)
///   - Heartbeat enforcement: reverts if no price update within heartbeat period
///   - Max deviation check: rejects single-update outliers
///   - Per-token configuration for decimals and heartbeat
contract TWAPOracle is IPriceOracle, Ownable {
    // ──────────────────────────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────────────────────────

    struct Observation {
        uint256 price;
        uint256 timestamp;
        uint256 cumulativePrice; // Cumulative price-seconds for TWAP
    }

    struct TokenConfig {
        uint8 decimals;
        uint256 heartbeat;       // Max seconds between updates
        uint256 maxDeviation;    // Max % deviation from last price (BPS, e.g., 5000 = 50%)
        uint16 bufferSize;       // Ring buffer capacity
        bool configured;
    }

    // ──────────────────────────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────────────────────────

    /// @notice Per-token configuration.
    mapping(address => TokenConfig) public tokenConfigs;

    /// @notice Ring buffer of observations per token.
    mapping(address => Observation[]) internal _observations;

    /// @notice Current write index in the ring buffer per token.
    mapping(address => uint256) internal _currentIndex;

    /// @notice Number of observations stored (capped at bufferSize).
    mapping(address => uint256) internal _observationCount;

    /// @notice TWAP calculation window in seconds.
    uint256 public twapWindow;

    /// @notice Global stale price threshold (fallback for tokens without custom heartbeat).
    uint256 public stalePriceThreshold;

    /// @notice Authorized price feeders.
    mapping(address => bool) public authorizedFeeders;

    // ──────────────────────────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────────────────────────

    error HeartbeatExceeded(address token, uint256 elapsed, uint256 heartbeat);
    error StalePrice(address token);
    error DeviationTooHigh(address token, uint256 oldPrice, uint256 newPrice, uint256 deviationBps);
    error TokenNotConfigured(address token);
    error ZeroPriceNotAllowed();
    error ArrayLengthMismatch();
    error NotAuthorizedFeeder();
    error InsufficientObservations(address token);

    // ──────────────────────────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────────────────────────

    modifier onlyFeeder() {
        if (!authorizedFeeders[msg.sender] && msg.sender != owner()) revert NotAuthorizedFeeder();
        _;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────────────────────────

    constructor(
        uint256 _stalePriceThreshold,
        uint256 _twapWindow
    ) Ownable(msg.sender) {
        stalePriceThreshold = _stalePriceThreshold;
        twapWindow = _twapWindow;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Admin
    // ──────────────────────────────────────────────────────────────────

    function configureToken(
        address token,
        uint8 decimals,
        uint256 heartbeat,
        uint256 maxDeviation,
        uint16 bufferSize
    ) external onlyOwner {
        tokenConfigs[token] = TokenConfig({
            decimals: decimals,
            heartbeat: heartbeat,
            maxDeviation: maxDeviation,
            bufferSize: bufferSize,
            configured: true
        });

        // Initialize ring buffer if needed
        if (_observations[token].length < bufferSize) {
            // Extend buffer
            while (_observations[token].length < bufferSize) {
                _observations[token].push(Observation(0, 0, 0));
            }
        }
    }

    function setAuthorizedFeeder(address feeder, bool authorized) external onlyOwner {
        authorizedFeeders[feeder] = authorized;
    }

    function setTwapWindow(uint256 _window) external onlyOwner {
        twapWindow = _window;
    }

    function setStalePriceThreshold(uint256 threshold) external onlyOwner {
        stalePriceThreshold = threshold;
    }

    function setTokenDecimals(address token, uint8 decimals) external onlyOwner {
        tokenConfigs[token].decimals = decimals;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Price updates
    // ──────────────────────────────────────────────────────────────────

    function setPrice(address token, uint256 priceUSD) external onlyFeeder {
        _setPrice(token, priceUSD);
    }

    function _setPrice(address token, uint256 priceUSD) internal {
        if (priceUSD == 0) revert ZeroPriceNotAllowed();
        TokenConfig storage config = tokenConfigs[token];
        if (!config.configured) revert TokenNotConfigured(token);

        // Deviation check against last observation
        uint256 count = _observationCount[token];
        if (count > 0) {
            uint256 lastIdx = _currentIndex[token] == 0
                ? _observations[token].length - 1
                : _currentIndex[token] - 1;
            uint256 lastPrice = _observations[token][lastIdx].price;

            if (lastPrice > 0 && config.maxDeviation > 0) {
                uint256 deviation = _calculateDeviation(lastPrice, priceUSD);
                if (deviation > config.maxDeviation) {
                    revert DeviationTooHigh(token, lastPrice, priceUSD, deviation);
                }
            }
        }

        // Calculate cumulative price
        uint256 cumulative;
        if (count > 0) {
            uint256 lastIdx = _currentIndex[token] == 0
                ? _observations[token].length - 1
                : _currentIndex[token] - 1;
            Observation storage lastObs = _observations[token][lastIdx];
            uint256 elapsed = block.timestamp - lastObs.timestamp;
            cumulative = lastObs.cumulativePrice + (lastObs.price * elapsed);
        }

        // Write observation to ring buffer
        uint256 writeIdx = _currentIndex[token];
        uint256 oldPrice = _observations[token][writeIdx].price;

        _observations[token][writeIdx] = Observation({
            price: priceUSD,
            timestamp: block.timestamp,
            cumulativePrice: cumulative
        });

        _currentIndex[token] = (writeIdx + 1) % config.bufferSize;
        if (count < config.bufferSize) {
            _observationCount[token] = count + 1;
        }

        emit Events.PriceUpdated(token, oldPrice, priceUSD, block.timestamp);
    }

    function setBatchPrices(
        address[] calldata tokens,
        uint256[] calldata prices
    ) external onlyFeeder {
        if (tokens.length != prices.length) revert ArrayLengthMismatch();
        for (uint256 i; i < tokens.length; ++i) {
            _setPrice(tokens[i], prices[i]);
        }
    }

    // ──────────────────────────────────────────────────────────────────
    //  Price reads
    // ──────────────────────────────────────────────────────────────────

    /// @notice Returns the latest spot price with heartbeat enforcement.
    function getPrice(address token) external view returns (uint256) {
        _enforceHeartbeat(token);
        return _getLatestPrice(token);
    }

    /// @notice Returns the TWAP over the configured window.
    function getTWAP(address token) external view returns (uint256) {
        _enforceHeartbeat(token);
        return _calculateTWAP(token);
    }

    function getDecimals(address token) external view returns (uint8) {
        return tokenConfigs[token].decimals;
    }

    function isPriceStale(address token) external view returns (bool) {
        uint256 count = _observationCount[token];
        if (count == 0) return true;

        uint256 lastIdx = _currentIndex[token] == 0
            ? _observations[token].length - 1
            : _currentIndex[token] - 1;
        uint256 lastTime = _observations[token][lastIdx].timestamp;

        uint256 threshold = tokenConfigs[token].heartbeat > 0
            ? tokenConfigs[token].heartbeat
            : stalePriceThreshold;

        return block.timestamp - lastTime > threshold;
    }

    /// @notice Returns the latest observation details.
    function getLatestObservation(address token)
        external
        view
        returns (uint256 price, uint256 timestamp, uint256 cumulativePrice)
    {
        uint256 count = _observationCount[token];
        if (count == 0) return (0, 0, 0);

        uint256 lastIdx = _currentIndex[token] == 0
            ? _observations[token].length - 1
            : _currentIndex[token] - 1;
        Observation storage obs = _observations[token][lastIdx];
        return (obs.price, obs.timestamp, obs.cumulativePrice);
    }

    function getObservationCount(address token) external view returns (uint256) {
        return _observationCount[token];
    }

    // ──────────────────────────────────────────────────────────────────
    //  Internal
    // ──────────────────────────────────────────────────────────────────

    function _getLatestPrice(address token) internal view returns (uint256) {
        uint256 count = _observationCount[token];
        if (count == 0) revert InsufficientObservations(token);

        uint256 lastIdx = _currentIndex[token] == 0
            ? _observations[token].length - 1
            : _currentIndex[token] - 1;
        return _observations[token][lastIdx].price;
    }

    function _calculateTWAP(address token) internal view returns (uint256) {
        uint256 count = _observationCount[token];
        if (count < 2) {
            // Not enough data for TWAP — return spot
            return _getLatestPrice(token);
        }

        // Find the oldest observation within the TWAP window
        uint256 targetTime = block.timestamp > twapWindow
            ? block.timestamp - twapWindow
            : 0;

        uint256 bufSize = _observations[token].length;
        uint256 newestIdx = _currentIndex[token] == 0
            ? bufSize - 1
            : _currentIndex[token] - 1;

        Observation storage newest = _observations[token][newestIdx];

        // Current cumulative (extend to now)
        uint256 currentCumulative = newest.cumulativePrice
            + newest.price * (block.timestamp - newest.timestamp);

        // Walk backwards to find the observation closest to targetTime
        uint256 oldestValidIdx = newestIdx;
        uint256 oldestCumulative = currentCumulative;

        for (uint256 i = 1; i < count; ++i) {
            uint256 checkIdx = (newestIdx + bufSize - i) % bufSize;
            Observation storage obs = _observations[token][checkIdx];

            if (obs.timestamp == 0) break; // uninitialised slot
            if (obs.timestamp <= targetTime) {
                // Interpolate cumulative at targetTime
                uint256 elapsed = targetTime - obs.timestamp;
                oldestCumulative = obs.cumulativePrice + (obs.price * elapsed);
                break;
            }
            oldestValidIdx = checkIdx;
            oldestCumulative = obs.cumulativePrice;
        }

        uint256 timeSpan = block.timestamp > _observations[token][oldestValidIdx].timestamp
            ? block.timestamp - _observations[token][oldestValidIdx].timestamp
            : 1; // avoid division by zero

        if (currentCumulative <= oldestCumulative) {
            return _getLatestPrice(token);
        }

        return (currentCumulative - oldestCumulative) / timeSpan;
    }

    function _enforceHeartbeat(address token) internal view {
        uint256 count = _observationCount[token];
        if (count == 0) revert InsufficientObservations(token);

        uint256 lastIdx = _currentIndex[token] == 0
            ? _observations[token].length - 1
            : _currentIndex[token] - 1;
        uint256 lastTime = _observations[token][lastIdx].timestamp;

        uint256 heartbeat = tokenConfigs[token].heartbeat > 0
            ? tokenConfigs[token].heartbeat
            : stalePriceThreshold;

        uint256 elapsed = block.timestamp - lastTime;
        if (elapsed > heartbeat) {
            revert HeartbeatExceeded(token, elapsed, heartbeat);
        }
    }

    function _calculateDeviation(
        uint256 oldPrice,
        uint256 newPrice
    ) internal pure returns (uint256) {
        uint256 diff = oldPrice > newPrice
            ? oldPrice - newPrice
            : newPrice - oldPrice;
        return (diff * 10_000) / oldPrice;
    }
}
