// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library LoanMath {
    uint256 internal constant YEAR = 365 days;
    uint256 internal constant BPS = 10_000;
    uint256 internal constant RAY = 1e27;

    function calculateInterest(
        uint256 principal,
        uint256 rateBps,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        return Math.mulDiv(principal, rateBps * timeElapsed, YEAR * BPS);
    }

    function calculateCompoundInterest(
        uint256 principal,
        uint256 rateBps,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        uint256 rate = Math.mulDiv(rateBps, RAY, BPS);
        uint256 timeFraction = Math.mulDiv(rate, timeElapsed, YEAR);
        uint256 secondTerm = Math.mulDiv(timeFraction, timeFraction, 2 * RAY);
        uint256 multiplier = RAY + timeFraction + secondTerm;
        return Math.mulDiv(principal, multiplier, RAY) - principal;
    }

    function calculateShares(
        uint256 amount,
        uint256 totalShares,
        uint256 totalDeposited
    ) internal pure returns (uint256) {
        if (totalShares == 0 || totalDeposited == 0) return amount;
        return Math.mulDiv(amount, totalShares, totalDeposited);
    }

    function calculateAmountFromShares(
        uint256 shares,
        uint256 totalShares,
        uint256 totalDeposited
    ) internal pure returns (uint256) {
        if (totalShares == 0) return 0;
        return Math.mulDiv(shares, totalDeposited, totalShares);
    }

    function bpsToRay(uint256 bps) internal pure returns (uint256) {
        return Math.mulDiv(bps, RAY, BPS);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return Math.min(a, b);
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return Math.max(a, b);
    }
}
