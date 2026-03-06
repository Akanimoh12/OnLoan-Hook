// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library HealthFactor {
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant BPS = 10_000;

    function calculateHealthFactor(
        uint256 collateralValueUSD,
        uint256 debtValueUSD,
        uint256 liquidationThresholdBps
    ) internal pure returns (uint256) {
        if (debtValueUSD == 0) return type(uint256).max;
        return Math.mulDiv(
            Math.mulDiv(collateralValueUSD, liquidationThresholdBps, BPS),
            PRECISION,
            debtValueUSD
        );
    }

    function isLiquidatable(uint256 healthFactor) internal pure returns (bool) {
        return healthFactor < PRECISION;
    }

    function calculateMaxBorrowable(
        uint256 collateralValueUSD,
        uint256 maxLTVBps
    ) internal pure returns (uint256) {
        return Math.mulDiv(collateralValueUSD, maxLTVBps, BPS);
    }
}
