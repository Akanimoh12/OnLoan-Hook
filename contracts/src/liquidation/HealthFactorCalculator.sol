// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {HealthFactor} from "../libraries/HealthFactor.sol";
import {InterestAccrual} from "../libraries/InterestAccrual.sol";
import {CollateralValuation} from "../libraries/CollateralValuation.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {Loan} from "../types/LoanTypes.sol";

library HealthFactorCalculator {
    function computeHealthFactor(
        address borrower,
        ILoanManager loanManager,
        ICollateralManager collateralManager,
        IPriceOracle priceOracle
    ) internal view returns (uint256) {
        Loan memory loan = loanManager.getLoan(borrower);
        if (!loan.active) return type(uint256).max;
        uint256 debt = InterestAccrual.getOutstandingDebt(loan);
        uint256 price = priceOracle.getPrice(loan.collateralToken);
        uint8 decimals = priceOracle.getDecimals(loan.collateralToken);
        uint256 collateralValue = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, price, decimals);
        uint256 threshold = collateralManager.getCollateralInfo(loan.collateralToken).liquidationThreshold;
        return HealthFactor.calculateHealthFactor(collateralValue, debt, threshold);
    }

    function batchComputeHealthFactors(
        address[] memory borrowers,
        ILoanManager loanManager,
        ICollateralManager collateralManager,
        IPriceOracle priceOracle
    ) internal view returns (uint256[] memory) {
        uint256[] memory factors = new uint256[](borrowers.length);
        for (uint256 i; i < borrowers.length; ++i) {
            factors[i] = computeHealthFactor(borrowers[i], loanManager, collateralManager, priceOracle);
        }
        return factors;
    }
}
