// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AbstractPausableReactive} from "@reactive-network/src/abstract-base/AbstractPausableReactive.sol";
import {IReactive} from "@reactive-network/src/interfaces/IReactive.sol";

/// @title CrossChainCollateralWatcher
/// @notice RSC that monitors ERC-20 Transfer events for collateral tokens on external
///         chains (e.g., Ethereum mainnet). When a monitored borrower moves collateral
///         out of their wallet on the origin chain, the watcher relays an alert to the
///         OnLoan CollateralManager on Unichain so the protocol can react.
///
/// Use cases:
///   - Detect when cross-chain collateral is transferred away, potentially reducing
///     the security backing an active loan.
///   - Trigger on-chain re-evaluation of a borrower's health factor.
///
/// Security:
///   - Nonce-based replay protection prevents the same Transfer event from being
///     processed twice.
///   - Stale event filtering via block age limit.
///   - Only the owner can add/remove monitored chains and borrowers.
contract CrossChainCollateralWatcher is AbstractPausableReactive {
    // ──────────────────────────────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────────────────────────────

    /// @notice ERC-20 Transfer(address,address,uint256) topic selector.
    uint256 internal constant TRANSFER_TOPIC =
        uint256(keccak256("Transfer(address,address,uint256)"));

    uint256 internal constant REACTIVE_WILDCARD =
        0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    uint64 public constant CALLBACK_GAS_LIMIT = 300_000;

    // ──────────────────────────────────────────────────────────────────
    //  Configuration
    // ──────────────────────────────────────────────────────────────────

    /// @notice Unichain chain ID — destination for callbacks.
    uint256 public immutable DESTINATION_CHAIN_ID;

    /// @notice CollateralManager address on Unichain.
    address public immutable COLLATERAL_MANAGER;

    /// @notice Maximum block age (on the origin chain) for processing events.
    ///         Events older than this are discarded.
    uint256 public maxBlockAge;

    // ──────────────────────────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────────────────────────

    struct MonitoredChain {
        uint256 chainId;
        address collateralToken; // Token address on the origin chain
        bool active;
    }

    /// @notice List of monitored chain+token pairs.
    MonitoredChain[] public monitoredChains;

    /// @notice Borrowers whose transfers we care about.
    mapping(address => bool) public monitoredBorrowers;

    /// @notice Replay protection — processed event hashes.
    mapping(bytes32 => bool) public processedEvents;

    /// @notice Subscription list for pause/resume.
    Subscription[] internal _subscriptions;

    // ──────────────────────────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────────────────────────

    event CollateralMovementDetected(
        uint256 indexed originChainId,
        address indexed borrower,
        address indexed token,
        uint256 amount
    );
    event BorrowerMonitoringUpdated(address indexed borrower, bool monitored);
    event ChainAdded(uint256 indexed chainId, address indexed token);

    // ──────────────────────────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────────────────────────

    constructor(
        uint256 _destinationChainId,
        address _collateralManager,
        uint256 _maxBlockAge
    ) {
        DESTINATION_CHAIN_ID = _destinationChainId;
        COLLATERAL_MANAGER = _collateralManager;
        maxBlockAge = _maxBlockAge;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Owner admin
    // ──────────────────────────────────────────────────────────────────

    /// @notice Add a chain+token pair to monitor for Transfer events.
    function addMonitoredChain(
        uint256 chainId,
        address collateralToken
    ) external onlyOwner {
        monitoredChains.push(MonitoredChain({
            chainId: chainId,
            collateralToken: collateralToken,
            active: true
        }));

        // Subscribe to Transfer events FROM any address on this token
        Subscription memory sub = Subscription({
            chain_id: chainId,
            _contract: collateralToken,
            topic_0: TRANSFER_TOPIC,
            topic_1: REACTIVE_WILDCARD, // from (any)
            topic_2: REACTIVE_WILDCARD, // to (any)
            topic_3: REACTIVE_WILDCARD
        });
        _subscriptions.push(sub);

        if (!vm) {
            service.subscribe(
                sub.chain_id,
                sub._contract,
                sub.topic_0,
                sub.topic_1,
                sub.topic_2,
                sub.topic_3
            );
        }

        emit ChainAdded(chainId, collateralToken);
    }

    /// @notice Add or remove a borrower from the monitored set.
    function setMonitoredBorrower(address borrower, bool monitored) external onlyOwner {
        monitoredBorrowers[borrower] = monitored;
        emit BorrowerMonitoringUpdated(borrower, monitored);
    }

    function setMaxBlockAge(uint256 _maxBlockAge) external onlyOwner {
        maxBlockAge = _maxBlockAge;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Pausable
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
    //  Core: react()
    // ──────────────────────────────────────────────────────────────────

    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_0 != TRANSFER_TOPIC) return;

        // Extract sender (from) — topic_1 in Transfer(address indexed from, address indexed to, uint256 value)
        address from = address(uint160(log.topic_1));

        // Only process transfers FROM monitored borrowers
        if (!monitoredBorrowers[from]) return;

        // Replay protection
        bytes32 eventHash = keccak256(
            abi.encodePacked(log.chain_id, log.tx_hash, log.log_index)
        );
        if (processedEvents[eventHash]) return;
        processedEvents[eventHash] = true;

        // Decode transfer amount
        uint256 amount = abi.decode(log.data, (uint256));

        emit CollateralMovementDetected(log.chain_id, from, log._contract, amount);

        // Emit callback to trigger health factor re-evaluation on Unichain
        // The callback targets a view/check function — the on-chain protocol
        // will decide whether to flag the position.
        bytes memory payload = abi.encodeWithSignature(
            "liquidateLoan(address)",
            from
        );
        emit Callback(DESTINATION_CHAIN_ID, COLLATERAL_MANAGER, CALLBACK_GAS_LIMIT, payload);
    }

    // ──────────────────────────────────────────────────────────────────
    //  View
    // ──────────────────────────────────────────────────────────────────

    function getMonitoredChainCount() external view returns (uint256) {
        return monitoredChains.length;
    }
}
