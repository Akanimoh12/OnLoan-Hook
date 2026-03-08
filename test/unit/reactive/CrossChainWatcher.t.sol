// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IReactive} from "@reactive-network/src/interfaces/IReactive.sol";
import {CrossChainCollateralWatcher} from "../../../contracts/src/reactive/CrossChainCollateralWatcher.sol";

contract CrossChainWatcherTest is Test {
    CrossChainCollateralWatcher public watcher;

    address public collateralManager = makeAddr("collateralManager");
    address public wethMainnet = makeAddr("WETH_MAINNET");
    address public borrower1 = makeAddr("borrower1");
    address public borrower2 = makeAddr("borrower2");
    address public randomUser = makeAddr("randomUser");

    uint256 constant UNICHAIN_ID = 1301;
    uint256 constant ETH_MAINNET_ID = 1;

    uint256 constant TRANSFER_TOPIC =
        uint256(keccak256("Transfer(address,address,uint256)"));

    function setUp() public {
        watcher = new CrossChainCollateralWatcher(
            UNICHAIN_ID,
            collateralManager,
            1000 // max block age
        );

        watcher.addMonitoredChain(ETH_MAINNET_ID, wethMainnet);
        watcher.setMonitoredBorrower(borrower1, true);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Deployment
    // ══════════════════════════════════════════════════════════════════

    function test_deployment() public view {
        assertEq(watcher.DESTINATION_CHAIN_ID(), UNICHAIN_ID);
        assertEq(watcher.COLLATERAL_MANAGER(), collateralManager);
        assertEq(watcher.maxBlockAge(), 1000);
        assertEq(watcher.getMonitoredChainCount(), 1);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Monitored borrower transfers trigger callback
    // ══════════════════════════════════════════════════════════════════

    function test_monitoredBorrowerTransfer_triggersCallback() public {
        vm.recordLogs();

        IReactive.LogRecord memory log = _makeTransferLog(
            ETH_MAINNET_ID,
            wethMainnet,
            borrower1,
            randomUser,
            5 ether,
            1 // unique tx hash
        );
        watcher.react(log);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool callbackEmitted = false;
        bool movementDetected = false;
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        bytes32 movementTopic = keccak256("CollateralMovementDetected(uint256,address,address,uint256)");

        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackEmitted = true;
            if (entries[i].topics[0] == movementTopic) movementDetected = true;
        }

        assertTrue(callbackEmitted, "Should emit Callback");
        assertTrue(movementDetected, "Should emit CollateralMovementDetected");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Non-monitored borrower is ignored
    // ══════════════════════════════════════════════════════════════════

    function test_nonMonitoredBorrower_noCallback() public {
        vm.recordLogs();

        IReactive.LogRecord memory log = _makeTransferLog(
            ETH_MAINNET_ID,
            wethMainnet,
            borrower2, // not monitored
            randomUser,
            5 ether,
            2
        );
        watcher.react(log);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        bool callbackEmitted = false;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackEmitted = true;
        }
        assertFalse(callbackEmitted, "Should not emit Callback for non-monitored borrower");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Replay protection
    // ══════════════════════════════════════════════════════════════════

    function test_replayProtection() public {
        IReactive.LogRecord memory log = _makeTransferLog(
            ETH_MAINNET_ID,
            wethMainnet,
            borrower1,
            randomUser,
            5 ether,
            42 // same tx hash
        );

        // First call should work
        watcher.react(log);

        // Second call with same event should be ignored
        vm.recordLogs();
        watcher.react(log);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        bool callbackEmitted = false;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackEmitted = true;
        }
        assertFalse(callbackEmitted, "Should not process same event twice");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Non-Transfer events are ignored
    // ══════════════════════════════════════════════════════════════════

    function test_nonTransferEvent_ignored() public {
        vm.recordLogs();

        IReactive.LogRecord memory log = IReactive.LogRecord({
            chain_id: ETH_MAINNET_ID,
            _contract: wethMainnet,
            topic_0: uint256(keccak256("Approval(address,address,uint256)")),
            topic_1: uint256(uint160(borrower1)),
            topic_2: uint256(uint160(randomUser)),
            topic_3: 0,
            data: abi.encode(uint256(5 ether)),
            block_number: 0,
            op_code: 0,
            block_hash: 0,
            tx_hash: 100,
            log_index: 0
        });

        watcher.react(log);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        bool callbackEmitted = false;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackEmitted = true;
        }
        assertFalse(callbackEmitted);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Admin
    // ══════════════════════════════════════════════════════════════════

    function test_addMonitoredChain() public {
        address arbWeth = makeAddr("ARB_WETH");
        watcher.addMonitoredChain(42161, arbWeth);
        assertEq(watcher.getMonitoredChainCount(), 2);
    }

    function test_setMonitoredBorrower_toggle() public {
        watcher.setMonitoredBorrower(borrower2, true);
        assertTrue(watcher.monitoredBorrowers(borrower2));

        watcher.setMonitoredBorrower(borrower2, false);
        assertFalse(watcher.monitoredBorrowers(borrower2));
    }

    function test_onlyOwner_addMonitoredChain() public {
        vm.prank(borrower1);
        vm.expectRevert();
        watcher.addMonitoredChain(10, makeAddr("token"));
    }

    function test_onlyOwner_setMonitoredBorrower() public {
        vm.prank(borrower1);
        vm.expectRevert();
        watcher.setMonitoredBorrower(borrower2, true);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Helpers
    // ══════════════════════════════════════════════════════════════════

    function _makeTransferLog(
        uint256 chainId,
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 txHash
    ) internal pure returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chain_id: chainId,
            _contract: token,
            topic_0: TRANSFER_TOPIC,
            topic_1: uint256(uint160(from)),
            topic_2: uint256(uint160(to)),
            topic_3: 0,
            data: abi.encode(amount),
            block_number: 0,
            op_code: 0,
            block_hash: 0,
            tx_hash: txHash,
            log_index: 0
        });
    }
}
