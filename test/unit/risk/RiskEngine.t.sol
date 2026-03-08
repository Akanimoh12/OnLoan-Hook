// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {RiskEngine} from "../../../contracts/src/risk/RiskEngine.sol";
import {IRiskEngine} from "../../../contracts/src/interfaces/IRiskEngine.sol";
import {TestSetup} from "../../helpers/TestSetup.sol";

contract RiskEngineTest is TestSetup {
    RiskEngine public riskEngine;

    uint256 constant WARNING_THRESHOLD = 1.5e18;   // 150%
    uint256 constant CRITICAL_THRESHOLD = 1.2e18;   // 120%

    function setUp() public override {
        super.setUp();

        riskEngine = new RiskEngine(
            address(loanManager),
            address(collateralManager),
            address(priceOracle),
            WARNING_THRESHOLD,
            CRITICAL_THRESHOLD
        );
    }

    // ══════════════════════════════════════════════════════════════════
    //  Deployment
    // ══════════════════════════════════════════════════════════════════

    function test_deployment() public view {
        assertEq(riskEngine.warningThreshold(), WARNING_THRESHOLD);
        assertEq(riskEngine.criticalThreshold(), CRITICAL_THRESHOLD);
    }

    // ══════════════════════════════════════════════════════════════════
    //  assessRisk — no active loan
    // ══════════════════════════════════════════════════════════════════

    function test_assessRisk_noLoan() public view {
        IRiskEngine.RiskAssessment memory result = riskEngine.assessRisk(borrower1);
        assertEq(result.healthFactor, type(uint256).max);
        assertFalse(result.isLiquidatable);
        assertFalse(result.isWarning);
    }

    // ══════════════════════════════════════════════════════════════════
    //  assessRisk — healthy loan
    // ══════════════════════════════════════════════════════════════════

    function test_assessRisk_healthyLoan() public {
        // Pool uses e18 denomination internally
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 15_000e18, 30 days);

        IRiskEngine.RiskAssessment memory result = riskEngine.assessRisk(borrower1);

        // CV = 10 * 3000 = 30000, debt = 15000, threshold = 8000 BPS
        // HF = (30000 * 0.8 * 1e18) / 15000 = 1.6e18
        assertGt(result.healthFactor, WARNING_THRESHOLD);
        assertFalse(result.isLiquidatable);
        assertFalse(result.isWarning);
        assertEq(result.borrower, borrower1);
        assertGt(result.collateralValueUSD, 0);
        assertGt(result.debtValueUSD, 0);
    }

    // ══════════════════════════════════════════════════════════════════
    //  assessRisk — warning zone
    // ══════════════════════════════════════════════════════════════════

    function test_assessRisk_warningZone() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        // HF = (10*3000*0.8)/20000 = 24000/20000 = 1.2 → below warning(1.5), above liq(1.0)
        IRiskEngine.RiskAssessment memory result = riskEngine.assessRisk(borrower1);

        assertTrue(result.isWarning, "Should be in warning zone");
        assertFalse(result.isLiquidatable, "Should not be liquidatable yet");
    }

    // ══════════════════════════════════════════════════════════════════
    //  assessRisk — liquidatable
    // ══════════════════════════════════════════════════════════════════

    function test_assessRisk_liquidatable() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        // Crash price: HF = (10*2000*0.8)/20000 = 0.8 → liquidatable
        priceOracle.setPrice(address(weth), 2000e18);

        IRiskEngine.RiskAssessment memory result = riskEngine.assessRisk(borrower1);

        assertTrue(result.isLiquidatable);
        assertLt(result.healthFactor, 1e18);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Batch assessment
    // ══════════════════════════════════════════════════════════════════

    function test_batchAssessRisk() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 15_000e18, 30 days);

        _depositCollateral(borrower2, address(weth), 5 ether);
        _createLoan(borrower2, address(weth), 5 ether, 10_000e18, 30 days);

        address[] memory borrowers = new address[](2);
        borrowers[0] = borrower1;
        borrowers[1] = borrower2;

        IRiskEngine.RiskAssessment[] memory results = riskEngine.batchAssessRisk(borrowers);

        assertEq(results.length, 2);
        assertEq(results[0].borrower, borrower1);
        assertEq(results[1].borrower, borrower2);
        assertGt(results[0].healthFactor, 0);
        assertGt(results[1].healthFactor, 0);
    }

    // ══════════════════════════════════════════════════════════════════
    //  getAtRiskLoans
    // ══════════════════════════════════════════════════════════════════

    function test_getAtRiskLoans() public {
        _depositToPool(lender1, 100_000e18);

        // Borrower1: healthy — HF = (10*3000*0.8)/10000 = 2.4
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 10_000e18, 30 days);

        // Borrower2: at-risk — HF = (5*3000*0.8)/10000 = 1.2
        _depositCollateral(borrower2, address(weth), 5 ether);
        _createLoan(borrower2, address(weth), 5 ether, 10_000e18, 30 days);

        // 15000 BPS → HF < 1.5e18
        (address[] memory borrowers, uint256[] memory healthFactors) =
            riskEngine.getAtRiskLoans(15000);

        assertEq(borrowers.length, 1);
        assertEq(borrowers[0], borrower2);
        assertLt(healthFactors[0], 1.5e18);
    }

    function test_getAtRiskLoans_noRisk() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 5_000e18, 30 days);

        (address[] memory borrowers,) = riskEngine.getAtRiskLoans(15000);
        assertEq(borrowers.length, 0);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Stress test: simulatePriceImpact
    // ══════════════════════════════════════════════════════════════════

    function test_simulatePriceImpact() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        // Simulate ETH dropping to 2000
        IRiskEngine.StressResult[] memory results =
            riskEngine.simulatePriceImpact(address(weth), 2000e18);

        assertEq(results.length, 1);
        assertEq(results[0].borrower, borrower1);
        assertGt(results[0].currentHealthFactor, 1e18);
        assertLt(results[0].stressedHealthFactor, 1e18);
        assertTrue(results[0].wouldBeLiquidatable);
    }

    function test_simulatePriceImpact_noAffectedBorrowers() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        // Simulate WBTC drop — borrower1 uses WETH, not affected
        IRiskEngine.StressResult[] memory results =
            riskEngine.simulatePriceImpact(address(wbtc), 30000e18);

        assertEq(results.length, 0);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Stress test: simulateMarketCrash
    // ══════════════════════════════════════════════════════════════════

    function test_simulateMarketCrash_30percent() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        // 30% crash: HF goes from 1.2 → 0.84
        IRiskEngine.StressResult[] memory results =
            riskEngine.simulateMarketCrash(3000);

        assertEq(results.length, 1);
        assertGt(results[0].currentHealthFactor, 1e18);
        assertLt(results[0].stressedHealthFactor, 1e18);
        assertTrue(results[0].wouldBeLiquidatable);
    }

    function test_simulateMarketCrash_10percent_stillSafe() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 10_000e18, 30 days);

        // 10% crash on healthy loan: HF 2.4 → 2.16
        IRiskEngine.StressResult[] memory results =
            riskEngine.simulateMarketCrash(1000);

        assertEq(results.length, 1);
        assertFalse(results[0].wouldBeLiquidatable);
    }

    // ══════════════════════════════════════════════════════════════════
    //  emitRiskWarnings
    // ══════════════════════════════════════════════════════════════════

    function test_emitRiskWarnings_emitsEvents() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        // HF ≈ 1.2 → below warning threshold (1.5)
        (uint256 warnings, uint256 liquidatable) = riskEngine.emitRiskWarnings();

        assertEq(warnings, 1);
        assertEq(liquidatable, 0);
    }

    function test_emitRiskWarnings_liquidatable() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        priceOracle.setPrice(address(weth), 2000e18);

        (uint256 warnings, uint256 liquidatable) = riskEngine.emitRiskWarnings();
        assertEq(warnings, 1);
        assertEq(liquidatable, 1);
    }

    function test_emitRiskWarnings_noWarnings() public {
        _depositToPool(lender1, 100_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 5_000e18, 30 days);

        // Very healthy: HF ≈ 4.8
        (uint256 warnings,) = riskEngine.emitRiskWarnings();
        assertEq(warnings, 0);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Admin
    // ══════════════════════════════════════════════════════════════════

    function test_setWarningThreshold() public {
        riskEngine.setWarningThreshold(2e18);
        assertEq(riskEngine.warningThreshold(), 2e18);
    }

    function test_setCriticalThreshold() public {
        riskEngine.setCriticalThreshold(1.1e18);
        assertEq(riskEngine.criticalThreshold(), 1.1e18);
    }

    function test_setDependencies() public {
        address newLM = makeAddr("newLM");
        address newCM = makeAddr("newCM");
        address newOracle = makeAddr("newOracle");

        riskEngine.setDependencies(newLM, newCM, newOracle);

        assertEq(address(riskEngine.loanManager()), newLM);
        assertEq(address(riskEngine.collateralManager()), newCM);
        assertEq(address(riskEngine.priceOracle()), newOracle);
    }

    function test_onlyOwner_setWarningThreshold() public {
        vm.prank(borrower1);
        vm.expectRevert();
        riskEngine.setWarningThreshold(2e18);
    }
}
