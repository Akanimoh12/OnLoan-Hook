// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {HealthFactor} from "../../contracts/src/libraries/HealthFactor.sol";

contract HealthFactorFuzzTest is Test {
    using HealthFactor for *;

    uint256 constant PRECISION = 1e18;
    uint256 constant BPS = 10_000;

    function testFuzz_healthFactor_zeroDebt_returnsMax(uint256 collateral) public pure {
        collateral = bound(collateral, 0, type(uint128).max);
        uint256 hf = HealthFactor.calculateHealthFactor(collateral, 0, 8000);
        assertEq(hf, type(uint256).max);
    }

    function testFuzz_healthFactor_proportionalToCollateral(uint256 c1, uint256 c2, uint256 debt) public pure {
        c1 = bound(c1, 1e18, type(uint96).max);
        c2 = bound(c2, 1e18, type(uint96).max);
        debt = bound(debt, 1e18, type(uint96).max);
        uint256 hf1 = HealthFactor.calculateHealthFactor(c1, debt, 8000);
        uint256 hf2 = HealthFactor.calculateHealthFactor(c2, debt, 8000);
        if (c1 > c2) {
            assertGe(hf1, hf2);
        } else if (c1 < c2) {
            assertLe(hf1, hf2);
        } else {
            assertEq(hf1, hf2);
        }
    }

    function testFuzz_healthFactor_inverseToDebt(uint256 collateral, uint256 d1, uint256 d2) public pure {
        collateral = bound(collateral, 1e18, type(uint96).max);
        d1 = bound(d1, 1e18, type(uint96).max);
        d2 = bound(d2, 1e18, type(uint96).max);
        uint256 hf1 = HealthFactor.calculateHealthFactor(collateral, d1, 8000);
        uint256 hf2 = HealthFactor.calculateHealthFactor(collateral, d2, 8000);
        if (d1 > d2) {
            assertLe(hf1, hf2);
        } else if (d1 < d2) {
            assertGe(hf1, hf2);
        } else {
            assertEq(hf1, hf2);
        }
    }

    function testFuzz_isLiquidatable_consistentWithHealthFactor(uint256 collateral, uint256 debt) public pure {
        collateral = bound(collateral, 1e18, type(uint96).max);
        debt = bound(debt, 1e18, type(uint96).max);
        uint256 hf = HealthFactor.calculateHealthFactor(collateral, debt, 8000);
        bool liquidatable = HealthFactor.isLiquidatable(hf);
        if (hf < PRECISION) {
            assertTrue(liquidatable);
        } else {
            assertFalse(liquidatable);
        }
    }

    function testFuzz_calculateMaxBorrowable_bounded(uint256 collateralValue, uint256 maxLTV) public pure {
        collateralValue = bound(collateralValue, 0, type(uint128).max);
        maxLTV = bound(maxLTV, 0, BPS);
        uint256 maxBorrow = HealthFactor.calculateMaxBorrowable(collateralValue, maxLTV);
        assertLe(maxBorrow, collateralValue);
    }

    function testFuzz_healthFactor_atExactThreshold(uint256 debt, uint256 thresholdBps) public pure {
        debt = bound(debt, 1e18, type(uint96).max);
        thresholdBps = bound(thresholdBps, 1, BPS);
        uint256 collateral = (debt * BPS) / thresholdBps;
        uint256 hf = HealthFactor.calculateHealthFactor(collateral, debt, thresholdBps);
        assertGe(hf, PRECISION - 1);
        assertLe(hf, PRECISION + 1);
    }
}
