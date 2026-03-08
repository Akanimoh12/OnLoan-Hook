// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IReactive} from "@reactive-network/src/interfaces/IReactive.sol";

/// @title MockReactiveCallback
/// @notice Mock contract for testing Reactive Network callbacks in Foundry.
///         Captures Callback events emitted by RSCs and records liquidation calls.
contract MockReactiveCallback {
    struct CallbackRecord {
        uint256 chainId;
        address target;
        uint64 gasLimit;
        bytes payload;
        uint256 timestamp;
    }

    struct LiquidationCall {
        address borrower;
        uint256 timestamp;
    }

    CallbackRecord[] public callbacks;
    LiquidationCall[] public liquidationCalls;

    /// @notice Simulates the OnLoanHook.liquidateLoan() entry point.
    function liquidateLoan(address borrower) external {
        liquidationCalls.push(LiquidationCall({
            borrower: borrower,
            timestamp: block.timestamp
        }));
    }

    function getCallbackCount() external view returns (uint256) {
        return callbacks.length;
    }

    function getLiquidationCallCount() external view returns (uint256) {
        return liquidationCalls.length;
    }

    function getLastLiquidationBorrower() external view returns (address) {
        if (liquidationCalls.length == 0) return address(0);
        return liquidationCalls[liquidationCalls.length - 1].borrower;
    }

    /// @notice Helper to craft a LogRecord for testing react() calls.
    function createLogRecord(
        uint256 chainId,
        address contractAddr,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3,
        bytes memory data
    ) external pure returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chain_id: chainId,
            _contract: contractAddr,
            topic_0: topic0,
            topic_1: topic1,
            topic_2: topic2,
            topic_3: topic3,
            data: data,
            block_number: 0,
            op_code: 0,
            block_hash: 0,
            tx_hash: 0,
            log_index: 0
        });
    }
}
