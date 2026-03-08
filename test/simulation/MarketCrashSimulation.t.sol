// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {RiskEngine} from "../../contracts/src/risk/RiskEngine.sol";
import {IRiskEngine} from "../../contracts/src/interfaces/IRiskEngine.sol";
import {TestSetup} from "../helpers/TestSetup.sol";

/// @title MarketCrashSimulation
/// @notice Stress tests simulating various market crash scenarios.
///         Validates protocol resilience under extreme conditions.
contract MarketCrashSimulation is TestSetup {
    RiskEngine public riskEngine;

    function setUp() public override {
        super.setUp();

        riskEngine = new RiskEngine(
            address(loanManager),
            address(collateralManager),
            address(priceOracle),
            1.5e18,  // warning threshold
            1.2e18   // critical threshold
        );

        // Setup: deposit liquidity
        _depositToPool(lender1, 100_000e18);
        _depositToPool(lender2, 100_000e18);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Scenario: Flash crash — 50% price drop
    // ══════════════════════════════════════════════════════════════════

    function test_flashCrash_50percent() public {
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        _depositCollateral(borrower2, address(weth), 10 ether);
        _createLoan(borrower2, address(weth), 10 ether, 10_000e18, 30 days);

        IRiskEngine.StressResult[] memory results =
            riskEngine.simulateMarketCrash(5000); // 50% drop

        uint256 liquidatable;
        for (uint256 i; i < results.length; ++i) {
            if (results[i].wouldBeLiquidatable) liquidatable++;
        }

        // B1: HF 1.2 → 0.6 (liquidatable), B2: HF 2.4 → 1.2 (borderline)
        assertEq(results.length, 2);
        assertGe(liquidatable, 1, "At least one position should be liquidatable at 50% crash");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Scenario: Gradual decline — 10% increments
    // ══════════════════════════════════════════════════════════════════

    function test_gradualDecline_10percentIncrements() public {
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        uint256[5] memory drops = [uint256(1000), 2000, 3000, 4000, 5000];
        uint256 liquidatableAtDrop;

        for (uint256 d; d < drops.length; ++d) {
            IRiskEngine.StressResult[] memory results =
                riskEngine.simulateMarketCrash(drops[d]);

            for (uint256 i; i < results.length; ++i) {
                if (results[i].wouldBeLiquidatable) {
                    liquidatableAtDrop = drops[d];
                    break;
                }
            }
            if (liquidatableAtDrop > 0) break;
        }

        // HF at 3000 = 1.2, needs ~17% drop → 20% bracket
        assertLe(liquidatableAtDrop, 3000, "Should become liquidatable within 30% drop");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Scenario: Black swan — 80% price crash on conservative position
    // ══════════════════════════════════════════════════════════════════

    function test_blackSwan_80percent() public {
        // Very conservative: 50 ETH for 10,000 borrow → HF = 12.0
        _depositCollateral(borrower1, address(weth), 50 ether);
        _createLoan(borrower1, address(weth), 50 ether, 10_000e18, 90 days);

        IRiskEngine.StressResult[] memory results =
            riskEngine.simulateMarketCrash(8000); // 80% drop

        assertEq(results.length, 1);
        // After 80% drop: price=600, CV=30000, HF=(30000*0.8)/10000 = 2.4 → still safe
        assertFalse(results[0].wouldBeLiquidatable,
            "Conservative position should survive 80% crash");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Scenario: Single token crash (WETH only)
    // ══════════════════════════════════════════════════════════════════

    function test_singleTokenCrash() public {
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        _depositCollateral(borrower2, address(wbtc), 1e8);
        _createLoan(borrower2, address(wbtc), 1e8, 40_000e18, 30 days);

        // Only WETH crashes to 50%
        IRiskEngine.StressResult[] memory wethResults =
            riskEngine.simulatePriceImpact(address(weth), 1500e18);

        // WBTC stable
        IRiskEngine.StressResult[] memory wbtcResults =
            riskEngine.simulatePriceImpact(address(wbtc), 60000e18);

        assertEq(wethResults.length, 1);
        assertTrue(wethResults[0].wouldBeLiquidatable, "WETH borrower should be liquidatable");

        assertEq(wbtcResults.length, 1);
        assertFalse(wbtcResults[0].wouldBeLiquidatable, "WBTC borrower should be fine");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Scenario: Interest accrual under stress
    // ══════════════════════════════════════════════════════════════════

    function test_interestAccrual_increasesRisk() public {
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 365 days);

        IRiskEngine.RiskAssessment memory before = riskEngine.assessRisk(borrower1);

        // Fast forward 180 days — interest accrues
        // Must refresh oracle price to avoid staleness
        vm.warp(block.timestamp + 180 days);
        priceOracle.setPrice(address(weth), 3000e18);

        IRiskEngine.RiskAssessment memory after_ = riskEngine.assessRisk(borrower1);

        assertLt(after_.healthFactor, before.healthFactor,
            "Health factor should decrease over time due to interest");
        assertGt(after_.debtValueUSD, before.debtValueUSD,
            "Debt should increase over time");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Scenario: Multiple borrowers, mixed collateral
    // ══════════════════════════════════════════════════════════════════

    function test_mixedCollateral_stressTest() public {
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        _depositCollateral(borrower2, address(wbtc), 1e8);
        _createLoan(borrower2, address(wbtc), 1e8, 40_000e18, 60 days);

        // Market crash — 40%
        IRiskEngine.StressResult[] memory results =
            riskEngine.simulateMarketCrash(4000);

        uint256 liquidatable;
        for (uint256 i; i < results.length; ++i) {
            if (results[i].wouldBeLiquidatable) liquidatable++;
        }

        // B1: HF 1.2→0.72, B2: HF 1.2→0.72 — both liquidatable
        assertEq(liquidatable, 2, "Both should be liquidatable at 40% crash");
    }

    // ══════════════════════════════════════════════════════════════════
    //  Scenario: Risk warnings cascade
    // ══════════════════════════════════════════════════════════════════

    function test_riskWarnings_cascade() public {
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 20_000e18, 30 days);

        _depositCollateral(borrower2, address(weth), 10 ether);
        _createLoan(borrower2, address(weth), 10 ether, 10_000e18, 30 days);

        // B1 HF ≈ 1.2 → warning, B2 HF ≈ 2.4 → safe
        (uint256 warnings,) = riskEngine.emitRiskWarnings();
        assertEq(warnings, 1, "Only the at-risk position should generate a warning");

        // Crash price to 1500 so both positions are at risk
        // B1: HF = (10*1500*0.8)/20000 = 0.6 → liquidatable
        // B2: HF = (10*1500*0.8)/10000 = 1.2 → warning
        priceOracle.setPrice(address(weth), 1500e18);

        (uint256 crashWarnings, uint256 liquidatable) = riskEngine.emitRiskWarnings();
        assertEq(crashWarnings, 2, "Both positions should generate warnings after crash");
        assertGt(liquidatable, 0, "At least one should be liquidatable");
    }
}
