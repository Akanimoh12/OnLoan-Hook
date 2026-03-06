// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library CollateralValuation {
    uint256 internal constant BPS = 10_000;

    function getCollateralValueUSD(
        uint256 collateralAmount,
        uint256 priceUSD,
        uint8 tokenDecimals
    ) internal pure returns (uint256) {
        return Math.mulDiv(collateralAmount, priceUSD, 10 ** tokenDecimals);
    }

    function getRequiredCollateral(
        uint256 borrowAmountUSD,
        uint256 collateralPriceUSD,
        uint256 collateralRatioBps,
        uint8 tokenDecimals
    ) internal pure returns (uint256) {
        uint256 requiredUSD = Math.mulDiv(borrowAmountUSD, collateralRatioBps, BPS);
        return Math.mulDiv(requiredUSD, 10 ** tokenDecimals, collateralPriceUSD);
    }
}
