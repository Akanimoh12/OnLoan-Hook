// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IReactive} from "@reactive-network/src/interfaces/IReactive.sol";
import {ReactiveMonitor} from "./ReactiveMonitor.sol";

/// @title LiquidationRSC
/// @notice Reactive Smart Contract that autonomously monitors OnLoan protocol health
///         factors and triggers liquidations when positions become undercollateralised.
///
/// Architecture:
///   - Deployed on Reactive Network, subscribes to Unichain events
///   - Tracks active loans via LoanCreated / LoanFullyRepaid / LoanLiquidated events
///   - Tracks collateral tokens via CollateralDeposited events
///   - Re-evaluates health factors on every PriceUpdated event
///   - Emits Callback events that Reactive Network relays to OnLoanHook.liquidateLoan()
///
/// Rate limiting:
///   - Per-borrower cooldown prevents duplicate liquidation attempts
///   - Grace period gives borrowers time to top up collateral before triggering
///
/// Security:
///   - On-chain health factor is the final arbiter — if the RSC triggers a callback
///     on a healthy loan, the on-chain LiquidationEngine simply reverts.
///   - Pausable via AbstractPausableReactive (owner can pause/resume subscriptions).
contract LiquidationRSC is ReactiveMonitor {
    // ──────────────────────────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────────────────────────

    struct TrackedLoan {
        address collateralToken;
        uint256 collateralAmount;
        uint256 borrowedAmount;
        uint256 interestRate; // BPS
        uint256 startTime;
        uint256 duration;
        bool active;
    }

    struct CollateralConfig {
        uint256 liquidationThreshold; // BPS (e.g., 8000 = 80%)
        uint8 decimals;
        bool configured;
    }

    // ──────────────────────────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────────────────────────

    /// @notice Active loan data per borrower.
    mapping(address => TrackedLoan) public trackedLoans;

    /// @notice Most recent collateral token deposited per borrower
    ///         (used to associate a token with a LoanCreated event).
    mapping(address => address) public borrowerCollateralToken;

    /// @notice Ordered list of active borrowers for iteration.
    address[] public activeBorrowers;

    /// @notice Index+1 into activeBorrowers (0 = not present).
    mapping(address => uint256) internal _borrowerIndex;

    /// @notice Latest known price per token (updated from PriceUpdated events).
    mapping(address => uint256) public tokenPrices;

    /// @notice Per-token collateral configuration (set at deploy / by owner).
    mapping(address => CollateralConfig) public collateralConfigs;

    /// @notice Timestamp of the last liquidation attempt per borrower.
    mapping(address => uint256) public lastLiquidationAttempt;

    // ──────────────────────────────────────────────────────────────────
    //  Config constants
    // ──────────────────────────────────────────────────────────────────
    uint256 public constant HEALTH_FACTOR_PRECISION = 1e18;
    uint256 public constant BPS = 10_000;
    uint256 public constant YEAR = 365 days;

    /// @notice Minimum seconds between consecutive liquidation callbacks for the same borrower.
    uint256 public liquidationCooldown;

    /// @notice Seconds a position must remain below threshold before the RSC triggers.
    uint256 public gracePeriod;

    /// @notice Warning threshold — emit warning events when HF drops below this (e.g., 1.3e18).
    uint256 public warningThreshold;

    /// @notice Addresses of contracts on origin chain whose events we subscribe to.
    address public immutable LOAN_MANAGER_ADDRESS;
    address public immutable LIQUIDATION_ENGINE_ADDRESS;
    address public immutable COLLATERAL_MANAGER_ADDRESS;

    /// @notice Subscription list for pause/resume.
    Subscription[] internal _subscriptions;

    // ──────────────────────────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────────────────────────
    event HealthFactorWarning(address indexed borrower, uint256 healthFactor);
    event CollateralConfigured(address indexed token, uint256 liquidationThreshold, uint8 decimals);

    // ──────────────────────────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────────────────────────

    constructor(
        uint256 _originChainId,
        address _hookAddress,
        address _oracleAddress,
        address _loanManagerAddress,
        address _liquidationEngineAddress,
        address _collateralManagerAddress,
        uint256 _liquidationCooldown,
        uint256 _gracePeriod,
        uint256 _warningThreshold
    )
        ReactiveMonitor(_originChainId, _hookAddress, _oracleAddress)
    {
        LOAN_MANAGER_ADDRESS = _loanManagerAddress;
        LIQUIDATION_ENGINE_ADDRESS = _liquidationEngineAddress;
        COLLATERAL_MANAGER_ADDRESS = _collateralManagerAddress;

        liquidationCooldown = _liquidationCooldown;
        gracePeriod = _gracePeriod;
        warningThreshold = _warningThreshold;

        // Build subscription list
        // 1. PriceUpdated from PriceOracle
        _subscriptions.push(Subscription({
            chain_id: _originChainId,
            _contract: _oracleAddress,
            topic_0: PRICE_UPDATED_TOPIC,
            topic_1: REACTIVE_IGNORE,
            topic_2: REACTIVE_IGNORE,
            topic_3: REACTIVE_IGNORE
        }));

        // 2. LoanCreated from LoanManager
        _subscriptions.push(Subscription({
            chain_id: _originChainId,
            _contract: _loanManagerAddress,
            topic_0: LOAN_CREATED_TOPIC,
            topic_1: REACTIVE_IGNORE,
            topic_2: REACTIVE_IGNORE,
            topic_3: REACTIVE_IGNORE
        }));

        // 3. LoanFullyRepaid from LoanManager
        _subscriptions.push(Subscription({
            chain_id: _originChainId,
            _contract: _loanManagerAddress,
            topic_0: LOAN_FULLY_REPAID_TOPIC,
            topic_1: REACTIVE_IGNORE,
            topic_2: REACTIVE_IGNORE,
            topic_3: REACTIVE_IGNORE
        }));

        // 4. LoanLiquidated from LiquidationEngine
        _subscriptions.push(Subscription({
            chain_id: _originChainId,
            _contract: _liquidationEngineAddress,
            topic_0: LOAN_LIQUIDATED_TOPIC,
            topic_1: REACTIVE_IGNORE,
            topic_2: REACTIVE_IGNORE,
            topic_3: REACTIVE_IGNORE
        }));

        // 5. CollateralDeposited from CollateralManager
        _subscriptions.push(Subscription({
            chain_id: _originChainId,
            _contract: _collateralManagerAddress,
            topic_0: COLLATERAL_DEPOSITED_TOPIC,
            topic_1: REACTIVE_IGNORE,
            topic_2: REACTIVE_IGNORE,
            topic_3: REACTIVE_IGNORE
        }));

        // Subscribe on Reactive Network (skipped in ReactVM / Foundry)
        if (!vm) {
            for (uint256 i; i < _subscriptions.length; ++i) {
                service.subscribe(
                    _subscriptions[i].chain_id,
                    _subscriptions[i]._contract,
                    _subscriptions[i].topic_0,
                    _subscriptions[i].topic_1,
                    _subscriptions[i].topic_2,
                    _subscriptions[i].topic_3
                );
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────
    //  Pausable subscriptions
    // ──────────────────────────────────────────────────────────────────

    function getPausableSubscriptions()
        internal
        view
        override
        returns (Subscription[] memory)
    {
        return _subscriptions;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Owner configuration
    // ──────────────────────────────────────────────────────────────────

    /// @notice Configure a collateral token's risk parameters.
    function setCollateralConfig(
        address token,
        uint256 liquidationThreshold,
        uint8 decimals
    ) external onlyOwner {
        collateralConfigs[token] = CollateralConfig({
            liquidationThreshold: liquidationThreshold,
            decimals: decimals,
            configured: true
        });
        emit CollateralConfigured(token, liquidationThreshold, decimals);
    }

    /// @notice Update rate-limiting parameters.
    function setLiquidationCooldown(uint256 _cooldown) external onlyOwner {
        liquidationCooldown = _cooldown;
    }

    function setGracePeriod(uint256 _period) external onlyOwner {
        gracePeriod = _period;
    }

    function setWarningThreshold(uint256 _threshold) external onlyOwner {
        warningThreshold = _threshold;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Core: react()
    // ──────────────────────────────────────────────────────────────────

    /// @notice Entry point called by the Reactive VM when a subscribed event fires.
    function react(LogRecord calldata log) external vmOnly {
        uint256 topic0 = log.topic_0;

        if (topic0 == PRICE_UPDATED_TOPIC) {
            _handlePriceUpdated(log);
        } else if (topic0 == LOAN_CREATED_TOPIC) {
            _handleLoanCreated(log);
        } else if (topic0 == LOAN_FULLY_REPAID_TOPIC) {
            _handleLoanRemoved(log);
        } else if (topic0 == LOAN_LIQUIDATED_TOPIC) {
            _handleLoanRemoved(log);
        } else if (topic0 == COLLATERAL_DEPOSITED_TOPIC) {
            _handleCollateralDeposited(log);
        }
    }

    // ──────────────────────────────────────────────────────────────────
    //  Event handlers
    // ──────────────────────────────────────────────────────────────────

    function _handlePriceUpdated(LogRecord calldata log) internal {
        // PriceUpdated(address indexed token, uint256 oldPrice, uint256 newPrice, uint256 timestamp)
        address token = address(uint160(log.topic_1));
        (, uint256 newPrice,) = abi.decode(log.data, (uint256, uint256, uint256));

        tokenPrices[token] = newPrice;
        emit PriceRecorded(token, newPrice);

        _checkLoansForLiquidation(token);
    }

    function _handleLoanCreated(LogRecord calldata log) internal {
        // LoanCreated(address indexed borrower, PoolId indexed poolId,
        //             uint256 collateralAmount, uint256 borrowedAmount, uint256 interestRate, uint256 duration)
        address borrower = address(uint160(log.topic_1));
        (uint256 collateralAmount, uint256 borrowedAmount, uint256 interestRate, uint256 duration) =
            abi.decode(log.data, (uint256, uint256, uint256, uint256));

        address colToken = borrowerCollateralToken[borrower];

        trackedLoans[borrower] = TrackedLoan({
            collateralToken: colToken,
            collateralAmount: collateralAmount,
            borrowedAmount: borrowedAmount,
            interestRate: interestRate,
            startTime: block.timestamp,
            duration: duration,
            active: true
        });

        _addBorrower(borrower);
        emit LoanTracked(borrower, collateralAmount, borrowedAmount);
    }

    function _handleLoanRemoved(LogRecord calldata log) internal {
        // Both LoanFullyRepaid and LoanLiquidated have borrower as topic_1
        address borrower = address(uint160(log.topic_1));
        if (trackedLoans[borrower].active) {
            trackedLoans[borrower].active = false;
            _removeBorrower(borrower);
            emit LoanUntracked(borrower);
        }
    }

    function _handleCollateralDeposited(LogRecord calldata log) internal {
        // CollateralDeposited(address indexed borrower, address indexed token, uint256 amount)
        address borrower = address(uint160(log.topic_1));
        address token = address(uint160(log.topic_2));
        borrowerCollateralToken[borrower] = token;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Liquidation check logic
    // ──────────────────────────────────────────────────────────────────

    /// @notice Iterates active borrowers whose collateral matches `token` and
    ///         emits Callback for any that fall below the liquidation threshold.
    function _checkLoansForLiquidation(address token) internal {
        uint256 price = tokenPrices[token];
        if (price == 0) return;

        uint256 len = activeBorrowers.length;
        for (uint256 i; i < len; ++i) {
            address borrower = activeBorrowers[i];
            TrackedLoan storage loan = trackedLoans[borrower];

            if (!loan.active || loan.collateralToken != token) continue;

            uint256 hf = _estimateHealthFactor(borrower, price);

            // Emit warning if below warning threshold but above liquidation
            if (hf < warningThreshold && hf >= HEALTH_FACTOR_PRECISION) {
                emit HealthFactorWarning(borrower, hf);
            }

            // Trigger liquidation if below threshold
            if (hf < HEALTH_FACTOR_PRECISION) {
                _tryTriggerLiquidation(borrower, hf);
            }
        }
    }

    /// @notice Estimates health factor using tracked loan state and latest price.
    ///         This is a conservative approximation — on-chain check is authoritative.
    function _estimateHealthFactor(
        address borrower,
        uint256 price
    ) internal view returns (uint256) {
        TrackedLoan storage loan = trackedLoans[borrower];
        CollateralConfig storage config = collateralConfigs[loan.collateralToken];

        if (!config.configured) {
            // Unknown collateral — can't estimate, return max (safe)
            return type(uint256).max;
        }

        // Estimate current debt with simple interest accrual
        uint256 timeElapsed = block.timestamp > loan.startTime
            ? block.timestamp - loan.startTime
            : 0;
        uint256 estimatedInterest;
        unchecked {
            estimatedInterest = (loan.borrowedAmount * loan.interestRate * timeElapsed)
                / (YEAR * BPS);
        }
        uint256 estimatedDebt = loan.borrowedAmount + estimatedInterest;
        if (estimatedDebt == 0) return type(uint256).max;

        // Collateral value in USD (price is already in 1e18 USD terms)
        uint256 collateralValueUSD;
        unchecked {
            collateralValueUSD = (loan.collateralAmount * price) / (10 ** config.decimals);
        }

        // HF = (collateralValue * liquidationThreshold / BPS) * PRECISION / debt
        uint256 adjustedCollateral = (collateralValueUSD * config.liquidationThreshold) / BPS;
        return (adjustedCollateral * HEALTH_FACTOR_PRECISION) / estimatedDebt;
    }

    /// @notice Triggers a liquidation callback after checking cooldown.
    function _tryTriggerLiquidation(address borrower, uint256 hf) internal {
        // Cooldown check (skip if never attempted)
        uint256 lastAttempt = lastLiquidationAttempt[borrower];
        if (lastAttempt > 0 && block.timestamp - lastAttempt < liquidationCooldown) {
            return;
        }

        // Grace period check — loan must have existed long enough
        TrackedLoan storage loan = trackedLoans[borrower];
        if (block.timestamp < loan.startTime + gracePeriod) {
            return;
        }

        lastLiquidationAttempt[borrower] = block.timestamp;

        // Emit Callback event — Reactive Network relays to OnLoanHook.liquidateLoan()
        bytes memory payload = abi.encodeWithSignature(
            "liquidateLoan(address)",
            borrower
        );
        emit Callback(ORIGIN_CHAIN_ID, HOOK_ADDRESS, CALLBACK_GAS_LIMIT, payload);
        emit LiquidationTriggered(borrower, hf);
    }

    // ──────────────────────────────────────────────────────────────────
    //  Borrower list management (O(1) add/remove)
    // ──────────────────────────────────────────────────────────────────

    function _addBorrower(address borrower) internal {
        if (_borrowerIndex[borrower] != 0) return; // already tracked
        activeBorrowers.push(borrower);
        _borrowerIndex[borrower] = activeBorrowers.length; // 1-indexed
    }

    function _removeBorrower(address borrower) internal {
        uint256 idx = _borrowerIndex[borrower];
        if (idx == 0) return; // not tracked

        uint256 lastIdx = activeBorrowers.length;
        if (idx != lastIdx) {
            address last = activeBorrowers[lastIdx - 1];
            activeBorrowers[idx - 1] = last;
            _borrowerIndex[last] = idx;
        }
        activeBorrowers.pop();
        delete _borrowerIndex[borrower];
    }

    // ──────────────────────────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────────────────────────

    function getActiveBorrowerCount() external view returns (uint256) {
        return activeBorrowers.length;
    }

    function getActiveBorrowers() external view returns (address[] memory) {
        return activeBorrowers;
    }

    function getEstimatedHealthFactor(address borrower) external view returns (uint256) {
        TrackedLoan storage loan = trackedLoans[borrower];
        if (!loan.active) return type(uint256).max;
        uint256 price = tokenPrices[loan.collateralToken];
        if (price == 0) return type(uint256).max;
        return _estimateHealthFactor(borrower, price);
    }
}
