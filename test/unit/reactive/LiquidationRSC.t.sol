// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IReactive} from "@reactive-network/src/interfaces/IReactive.sol";
import {LiquidationRSC} from "../../../contracts/src/reactive/LiquidationRSC.sol";
import {ReactiveMonitor} from "../../../contracts/src/reactive/ReactiveMonitor.sol";
import {MockReactiveCallback} from "../../helpers/MockReactiveCallback.sol";

contract LiquidationRSCTest is Test {
    LiquidationRSC public rsc;
    MockReactiveCallback public mockCallback;

    address public oracle = makeAddr("oracle");
    address public hook = makeAddr("hook");
    address public loanManager = makeAddr("loanManager");
    address public liquidationEngine = makeAddr("liquidationEngine");
    address public collateralManager = makeAddr("collateralManager");
    address public weth = makeAddr("WETH");
    address public wbtc = makeAddr("WBTC");
    address public borrower1 = makeAddr("borrower1");
    address public borrower2 = makeAddr("borrower2");

    uint256 constant CHAIN_ID = 1301;
    uint256 constant PRECISION = 1e18;

    // Event topic constants (must match ReactiveMonitor)
    uint256 constant PRICE_UPDATED_TOPIC =
        uint256(keccak256("PriceUpdated(address,uint256,uint256,uint256)"));
    uint256 constant LOAN_CREATED_TOPIC =
        uint256(keccak256("LoanCreated(address,bytes32,uint256,uint256,uint256,uint256)"));
    uint256 constant LOAN_FULLY_REPAID_TOPIC =
        uint256(keccak256("LoanFullyRepaid(address,bytes32)"));
    uint256 constant LOAN_LIQUIDATED_TOPIC =
        uint256(keccak256("LoanLiquidated(address,address,uint256,uint256,uint256)"));
    uint256 constant COLLATERAL_DEPOSITED_TOPIC =
        uint256(keccak256("CollateralDeposited(address,address,uint256)"));

    // Reactive Network's REACTIVE_IGNORE constant
    uint256 constant REACTIVE_IGNORE =
        0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    function setUp() public {
        mockCallback = new MockReactiveCallback();

        rsc = new LiquidationRSC(
            CHAIN_ID,
            hook,
            oracle,
            loanManager,
            liquidationEngine,
            collateralManager,
            5 minutes,   // cooldown
            30 seconds,  // grace period
            1.3e18       // warning threshold
        );

        // Configure collateral tokens
        rsc.setCollateralConfig(weth, 8000, 18);
        rsc.setCollateralConfig(wbtc, 8000, 8);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Deployment
    // ══════════════════════════════════════════════════════════════════

    function test_deployment_setsConfig() public view {
        assertEq(rsc.ORIGIN_CHAIN_ID(), CHAIN_ID);
        assertEq(rsc.HOOK_ADDRESS(), hook);
        assertEq(rsc.ORACLE_ADDRESS(), oracle);
        assertEq(rsc.liquidationCooldown(), 5 minutes);
        assertEq(rsc.gracePeriod(), 30 seconds);
        assertEq(rsc.warningThreshold(), 1.3e18);
    }

    function test_collateralConfig() public view {
        (uint256 threshold, uint8 decimals, bool configured) = rsc.collateralConfigs(weth);
        assertEq(threshold, 8000);
        assertEq(decimals, 18);
        assertTrue(configured);
    }

    // ══════════════════════════════════════════════════════════════════
    //  CollateralDeposited handling
    // ══════════════════════════════════════════════════════════════════

    function test_handleCollateralDeposited() public {
        IReactive.LogRecord memory log = _makeLog(
            collateralManager,
            COLLATERAL_DEPOSITED_TOPIC,
            uint256(uint160(borrower1)),
            uint256(uint160(weth)),
            0,
            abi.encode(uint256(10 ether))
        );

        rsc.react(log);
        assertEq(rsc.borrowerCollateralToken(borrower1), weth);
    }

    // ══════════════════════════════════════════════════════════════════
    //  LoanCreated handling
    // ══════════════════════════════════════════════════════════════════

    function test_handleLoanCreated() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        (
            address colToken,
            uint256 colAmount,
            uint256 borrowAmount,
            uint256 rate,
            ,
            uint256 duration,
            bool active
        ) = rsc.trackedLoans(borrower1);

        assertTrue(active);
        assertEq(colToken, weth);
        assertEq(colAmount, 10 ether);
        assertEq(borrowAmount, 20_000e18);
        assertEq(rate, 500);
        assertEq(duration, 30 days);
        assertEq(rsc.getActiveBorrowerCount(), 1);
    }

    function test_handleLoanCreated_multipleBorrowers() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        _depositCollateral(borrower2, wbtc);
        _createLoan(borrower2, 1e8, 40_000e18, 600, 60 days);

        assertEq(rsc.getActiveBorrowerCount(), 2);
    }

    // ══════════════════════════════════════════════════════════════════
    //  LoanFullyRepaid / LoanLiquidated handling
    // ══════════════════════════════════════════════════════════════════

    function test_handleLoanFullyRepaid() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);
        assertEq(rsc.getActiveBorrowerCount(), 1);

        // Simulate LoanFullyRepaid
        IReactive.LogRecord memory log = _makeLog(
            loanManager,
            LOAN_FULLY_REPAID_TOPIC,
            uint256(uint160(borrower1)),
            uint256(bytes32(uint256(1))), // poolId
            0,
            bytes("")
        );
        rsc.react(log);

        assertEq(rsc.getActiveBorrowerCount(), 0);
        (, , , , , , bool active) = rsc.trackedLoans(borrower1);
        assertFalse(active);
    }

    function test_handleLoanLiquidated() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        IReactive.LogRecord memory log = _makeLog(
            liquidationEngine,
            LOAN_LIQUIDATED_TOPIC,
            uint256(uint160(borrower1)),
            uint256(uint160(makeAddr("liquidator"))),
            0,
            abi.encode(uint256(10 ether), uint256(20_000e18), uint256(500))
        );
        rsc.react(log);

        assertEq(rsc.getActiveBorrowerCount(), 0);
    }

    // ══════════════════════════════════════════════════════════════════
    //  PriceUpdated — healthy loan (no liquidation triggered)
    // ══════════════════════════════════════════════════════════════════

    function test_priceUpdate_healthyLoan_noLiquidation() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        // Advance past grace period
        vm.warp(block.timestamp + 1 minutes);

        // Price stays at 3000 — loan is healthy
        // Collateral: 10 ETH * 3000 = 30,000 USD
        // Debt: 20,000 USD
        // HF = (30,000 * 0.8) / 20,000 = 1.2 → above 1.0
        vm.recordLogs();
        _updatePrice(weth, 3000e18, 3000e18);

        // Should NOT emit Callback
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool callbackEmitted = false;
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) {
                callbackEmitted = true;
            }
        }
        assertFalse(callbackEmitted, "Should not trigger liquidation for healthy loan");
    }

    // ══════════════════════════════════════════════════════════════════
    //  PriceUpdated — unhealthy loan (liquidation triggered)
    // ══════════════════════════════════════════════════════════════════

    function test_priceUpdate_unhealthyLoan_triggersLiquidation() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        // Advance past grace period
        vm.warp(block.timestamp + 1 minutes);

        // Price crashes to 2000 USD
        // Collateral: 10 ETH * 2000 = 20,000 USD
        // Debt: ~20,000 USD (+ tiny interest)
        // HF = (20,000 * 0.8) / 20,000 = 0.8 → below 1.0
        vm.recordLogs();
        _updatePrice(weth, 3000e18, 2000e18);

        // Should emit Callback and LiquidationTriggered
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool callbackEmitted = false;
        bool liquidationTriggered = false;
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        bytes32 liquidationTopic = keccak256("LiquidationTriggered(address,uint256)");

        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackEmitted = true;
            if (entries[i].topics[0] == liquidationTopic) liquidationTriggered = true;
        }
        assertTrue(callbackEmitted, "Should emit Callback for liquidation");
        assertTrue(liquidationTriggered, "Should emit LiquidationTriggered");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Rate limiting (cooldown)
    // ══════════════════════════════════════════════════════════════════

    function test_liquidationCooldown_preventsSpam() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);
        vm.warp(block.timestamp + 1 minutes);

        // First price crash — triggers liquidation
        _updatePrice(weth, 3000e18, 2000e18);

        // Second price update shortly after — should NOT trigger again
        vm.recordLogs();
        _updatePrice(weth, 2000e18, 1900e18);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        uint256 callbackCount;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackCount++;
        }
        assertEq(callbackCount, 0, "Should be rate-limited");
    }

    function test_liquidationCooldown_allowsAfterExpiry() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);
        vm.warp(block.timestamp + 1 minutes);

        // First crash
        _updatePrice(weth, 3000e18, 2000e18);

        // Advance past cooldown
        vm.warp(block.timestamp + 6 minutes);

        // Second crash — should trigger
        vm.recordLogs();
        _updatePrice(weth, 2000e18, 1800e18);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        bool callbackEmitted = false;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackEmitted = true;
        }
        assertTrue(callbackEmitted, "Should trigger after cooldown expires");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Grace period
    // ══════════════════════════════════════════════════════════════════

    function test_gracePeriod_preventsEarlyLiquidation() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        // Don't advance past grace period — should NOT trigger
        vm.recordLogs();
        _updatePrice(weth, 3000e18, 2000e18);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        bool callbackEmitted = false;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackEmitted = true;
        }
        assertFalse(callbackEmitted, "Should not trigger during grace period");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Warning events
    // ══════════════════════════════════════════════════════════════════

    function test_warningEmitted_whenBelowThreshold() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);
        vm.warp(block.timestamp + 1 minutes);

        // Price drops slightly — HF between warning (1.3) and liquidation (1.0)
        // At price 2800: CV = 28000, HF = (28000*0.8)/20000 = 1.12 → below 1.3 but above 1.0
        vm.recordLogs();
        _updatePrice(weth, 3000e18, 2800e18);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 warningTopic = keccak256("HealthFactorWarning(address,uint256)");
        bool warningEmitted = false;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == warningTopic) warningEmitted = true;
        }
        assertTrue(warningEmitted, "Should emit warning for at-risk position");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Health factor estimation
    // ══════════════════════════════════════════════════════════════════

    function test_getEstimatedHealthFactor() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        // Set price
        _updatePrice(weth, 0, 3000e18);

        uint256 hf = rsc.getEstimatedHealthFactor(borrower1);
        // CV = 10 * 3000 = 30000, threshold = 80%, debt ≈ 20000
        // HF ≈ (30000 * 0.8 / 20000) * 1e18 ≈ 1.2e18
        assertGt(hf, 1.1e18);
        assertLt(hf, 1.3e18);
    }

    function test_getEstimatedHealthFactor_inactiveLoan() public view {
        uint256 hf = rsc.getEstimatedHealthFactor(borrower1);
        assertEq(hf, type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Borrower list management
    // ══════════════════════════════════════════════════════════════════

    function test_borrowerList_addRemove() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);
        _depositCollateral(borrower2, weth);
        _createLoan(borrower2, 5 ether, 10_000e18, 500, 30 days);

        assertEq(rsc.getActiveBorrowerCount(), 2);

        // Remove borrower1
        IReactive.LogRecord memory log = _makeLog(
            loanManager,
            LOAN_FULLY_REPAID_TOPIC,
            uint256(uint160(borrower1)),
            0, 0, bytes("")
        );
        rsc.react(log);

        assertEq(rsc.getActiveBorrowerCount(), 1);
        address[] memory active = rsc.getActiveBorrowers();
        assertEq(active[0], borrower2);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Owner config updates
    // ══════════════════════════════════════════════════════════════════

    function test_setLiquidationCooldown() public {
        rsc.setLiquidationCooldown(10 minutes);
        assertEq(rsc.liquidationCooldown(), 10 minutes);
    }

    function test_setGracePeriod() public {
        rsc.setGracePeriod(2 minutes);
        assertEq(rsc.gracePeriod(), 2 minutes);
    }

    function test_setWarningThreshold() public {
        rsc.setWarningThreshold(1.5e18);
        assertEq(rsc.warningThreshold(), 1.5e18);
    }

    function test_onlyOwner_setCollateralConfig() public {
        vm.prank(borrower1);
        vm.expectRevert();
        rsc.setCollateralConfig(weth, 7000, 18);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Edge cases
    // ══════════════════════════════════════════════════════════════════

    function test_unknownCollateral_returnsMaxHF() public {
        address unknown = makeAddr("unknownToken");
        // Deposit unknown collateral
        IReactive.LogRecord memory depLog = _makeLog(
            collateralManager,
            COLLATERAL_DEPOSITED_TOPIC,
            uint256(uint160(borrower1)),
            uint256(uint160(unknown)),
            0,
            abi.encode(uint256(100))
        );
        rsc.react(depLog);

        _createLoan(borrower1, 100, 50, 500, 30 days);

        uint256 hf = rsc.getEstimatedHealthFactor(borrower1);
        assertEq(hf, type(uint256).max, "Unknown collateral should return max HF");
    }

    function test_zeroPrice_noLiquidation() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);
        vm.warp(block.timestamp + 1 minutes);

        // Price of 0 should not trigger
        // (tokenPrices[weth] == 0 initially, so _checkLoansForLiquidation returns early)
        vm.recordLogs();
        IReactive.LogRecord memory log = _makeLog(
            oracle,
            PRICE_UPDATED_TOPIC,
            uint256(uint160(makeAddr("otherToken"))), // different token
            0, 0,
            abi.encode(uint256(0), uint256(100e18), uint256(block.timestamp))
        );
        rsc.react(log);

        // No callback for weth borrowers since price of weth is still 0
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 callbackTopic = keccak256("Callback(uint256,address,uint64,bytes)");
        bool callbackEmitted = false;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == callbackTopic) callbackEmitted = true;
        }
        assertFalse(callbackEmitted);
    }

    function test_duplicateBorrowerAdd() public {
        _depositCollateral(borrower1, weth);
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        // Try to create same loan again — _addBorrower should handle duplicate
        // (In reality the on-chain LoanManager prevents this, but RSC should be safe)
        _createLoan(borrower1, 10 ether, 20_000e18, 500, 30 days);

        // Should still only have 1 entry
        assertEq(rsc.getActiveBorrowerCount(), 1);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Helpers
    // ══════════════════════════════════════════════════════════════════

    function _makeLog(
        address contractAddr,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3,
        bytes memory data
    ) internal view returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chain_id: CHAIN_ID,
            _contract: contractAddr,
            topic_0: topic0,
            topic_1: topic1,
            topic_2: topic2,
            topic_3: topic3,
            data: data,
            block_number: block.number,
            op_code: 0,
            block_hash: 0,
            tx_hash: 0,
            log_index: 0
        });
    }

    function _depositCollateral(address borrower, address token) internal {
        IReactive.LogRecord memory log = _makeLog(
            collateralManager,
            COLLATERAL_DEPOSITED_TOPIC,
            uint256(uint160(borrower)),
            uint256(uint160(token)),
            0,
            abi.encode(uint256(10 ether))
        );
        rsc.react(log);
    }

    function _createLoan(
        address borrower,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 interestRate,
        uint256 duration
    ) internal {
        IReactive.LogRecord memory log = _makeLog(
            loanManager,
            LOAN_CREATED_TOPIC,
            uint256(uint160(borrower)),
            uint256(bytes32(uint256(1))), // poolId
            0,
            abi.encode(collateralAmount, borrowAmount, interestRate, duration)
        );
        rsc.react(log);
    }

    function _updatePrice(address token, uint256 oldPrice, uint256 newPrice) internal {
        IReactive.LogRecord memory log = _makeLog(
            oracle,
            PRICE_UPDATED_TOPIC,
            uint256(uint160(token)),
            0, 0,
            abi.encode(oldPrice, newPrice, block.timestamp)
        );
        rsc.react(log);
    }
}
