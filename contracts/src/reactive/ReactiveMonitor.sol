// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AbstractPausableReactive} from "@reactive-network/src/abstract-base/AbstractPausableReactive.sol";

/// @title ReactiveMonitor
/// @notice Abstract base for OnLoan Reactive Smart Contracts (RSCs).
///         Provides shared configuration, event topic constants, and subscription helpers
///         for all OnLoan automation contracts deployed to the Reactive Network.
abstract contract ReactiveMonitor is AbstractPausableReactive {
    // ──────────────────────────────────────────────────────────────────
    //  Event topic selectors (keccak256 of the canonical ABI signature)
    // ──────────────────────────────────────────────────────────────────
    uint256 internal constant PRICE_UPDATED_TOPIC =
        uint256(keccak256("PriceUpdated(address,uint256,uint256,uint256)"));

    uint256 internal constant LOAN_CREATED_TOPIC =
        uint256(keccak256("LoanCreated(address,bytes32,uint256,uint256,uint256,uint256)"));

    uint256 internal constant LOAN_FULLY_REPAID_TOPIC =
        uint256(keccak256("LoanFullyRepaid(address,bytes32)"));

    uint256 internal constant LOAN_LIQUIDATED_TOPIC =
        uint256(keccak256("LoanLiquidated(address,address,uint256,uint256,uint256)"));

    uint256 internal constant COLLATERAL_DEPOSITED_TOPIC =
        uint256(keccak256("CollateralDeposited(address,address,uint256)"));

    uint256 internal constant HEALTH_FACTOR_UPDATED_TOPIC =
        uint256(keccak256("HealthFactorUpdated(address,uint256,uint256)"));

    // ──────────────────────────────────────────────────────────────────
    //  Shared configuration
    // ──────────────────────────────────────────────────────────────────

    /// @notice EIP-155 chain ID of the origin chain (Unichain) where OnLoan is deployed.
    uint256 public immutable ORIGIN_CHAIN_ID;

    /// @notice OnLoanHook address on the origin chain — target for liquidation callbacks.
    address public immutable HOOK_ADDRESS;

    /// @notice PriceOracle address on the origin chain — source of PriceUpdated events.
    address public immutable ORACLE_ADDRESS;

    /// @notice Gas limit for cross-chain callback execution.
    uint64 public constant CALLBACK_GAS_LIMIT = 500_000;

    // ──────────────────────────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────────────────────────
    event LiquidationTriggered(address indexed borrower, uint256 estimatedHealthFactor);
    event LoanTracked(address indexed borrower, uint256 collateralAmount, uint256 borrowedAmount);
    event LoanUntracked(address indexed borrower);
    event PriceRecorded(address indexed token, uint256 price);

    constructor(
        uint256 _originChainId,
        address _hookAddress,
        address _oracleAddress
    ) {
        ORIGIN_CHAIN_ID = _originChainId;
        HOOK_ADDRESS = _hookAddress;
        ORACLE_ADDRESS = _oracleAddress;
    }
}
