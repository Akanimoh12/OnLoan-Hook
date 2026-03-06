// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {LoanMath} from "../../contracts/src/libraries/LoanMath.sol";
import {CollateralValuation} from "../../contracts/src/libraries/CollateralValuation.sol";

contract CollateralRatioFuzzTest is Test {
    using LoanMath for *;
    using CollateralValuation for *;

    function testFuzz_calculateShares_roundTrip(
        uint256 amount,
        uint256 totalShares,
        uint256 totalDeposited
    ) public pure {
        amount = bound(amount, 1e18, type(uint96).max);
        totalShares = bound(totalShares, 1e18, type(uint96).max);
        totalDeposited = bound(totalDeposited, 1e18, type(uint96).max);

        uint256 shares = LoanMath.calculateShares(amount, totalShares, totalDeposited);
        uint256 amountBack = LoanMath.calculateAmountFromShares(shares, totalShares + shares, totalDeposited + amount);

        assertApproxEqRel(amountBack, amount, 1e15);
    }

    function testFuzz_calculateShares_initialDeposit(uint256 amount) public pure {
        amount = bound(amount, 1, type(uint128).max);
        uint256 shares = LoanMath.calculateShares(amount, 0, 0);
        assertEq(shares, amount);
    }

    function testFuzz_calculateShares_proportional(uint256 a1, uint256 a2, uint256 totalShares, uint256 totalDeposited)
        public
        pure
    {
        a1 = bound(a1, 1, type(uint64).max);
        a2 = bound(a2, 1, type(uint64).max);
        totalShares = bound(totalShares, 1, type(uint96).max);
        totalDeposited = bound(totalDeposited, 1, type(uint96).max);

        uint256 s1 = LoanMath.calculateShares(a1, totalShares, totalDeposited);
        uint256 s2 = LoanMath.calculateShares(a2, totalShares, totalDeposited);

        if (a1 > a2) {
            assertGe(s1, s2);
        } else if (a1 < a2) {
            assertLe(s1, s2);
        } else {
            assertEq(s1, s2);
        }
    }

    function testFuzz_collateralValuation_scalesLinearly(uint256 amount, uint256 price) public pure {
        amount = bound(amount, 1, type(uint96).max);
        price = bound(price, 1, type(uint96).max);

        uint256 val1 = CollateralValuation.getCollateralValueUSD(amount, price, 18);
        uint256 val2 = CollateralValuation.getCollateralValueUSD(amount * 2, price, 18);

        assertApproxEqAbs(val2, val1 * 2, 1);
    }

    function testFuzz_collateralValuation_priceScaling(uint256 amount, uint256 p1, uint256 p2) public pure {
        amount = bound(amount, 1e18, type(uint96).max);
        p1 = bound(p1, 1e18, type(uint96).max);
        p2 = bound(p2, 1e18, type(uint96).max);

        uint256 v1 = CollateralValuation.getCollateralValueUSD(amount, p1, 18);
        uint256 v2 = CollateralValuation.getCollateralValueUSD(amount, p2, 18);

        if (p1 > p2) {
            assertGe(v1, v2);
        } else if (p1 < p2) {
            assertLe(v1, v2);
        } else {
            assertEq(v1, v2);
        }
    }

    function testFuzz_requiredCollateral_inverseOfValuation(uint256 borrowAmount, uint256 price) public pure {
        borrowAmount = bound(borrowAmount, 1e18, type(uint96).max);
        price = bound(price, 1e18, type(uint96).max);

        uint256 required = CollateralValuation.getRequiredCollateral(borrowAmount, price, 10_000, 18);
        uint256 valueOfRequired = CollateralValuation.getCollateralValueUSD(required, price, 18);

        assertApproxEqRel(valueOfRequired, borrowAmount, 1e15);
    }

    function testFuzz_calculateInterest_proportionalToTime(uint256 principal, uint256 t1, uint256 t2) public pure {
        principal = bound(principal, 1e18, type(uint96).max);
        t1 = bound(t1, 1 days, 365 days);
        t2 = bound(t2, 1 days, 365 days);

        uint256 i1 = LoanMath.calculateInterest(principal, 1000, t1);
        uint256 i2 = LoanMath.calculateInterest(principal, 1000, t2);

        if (t1 > t2) {
            assertGe(i1, i2);
        } else if (t1 < t2) {
            assertLe(i1, i2);
        } else {
            assertEq(i1, i2);
        }
    }

    function testFuzz_calculateInterest_proportionalToRate(uint256 principal, uint256 r1, uint256 r2) public pure {
        principal = bound(principal, 1e18, type(uint96).max);
        r1 = bound(r1, 1, 5000);
        r2 = bound(r2, 1, 5000);
        uint256 time = 365 days;

        uint256 i1 = LoanMath.calculateInterest(principal, r1, time);
        uint256 i2 = LoanMath.calculateInterest(principal, r2, time);

        if (r1 > r2) {
            assertGe(i1, i2);
        } else if (r1 < r2) {
            assertLe(i1, i2);
        } else {
            assertEq(i1, i2);
        }
    }
}
