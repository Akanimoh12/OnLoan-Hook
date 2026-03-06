// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Loan} from "../types/LoanTypes.sol";
import {LoanMath} from "./LoanMath.sol";

library InterestAccrual {
    function accrueInterest(Loan memory loan) internal view returns (uint256) {
        if (!loan.active || block.timestamp <= loan.lastAccrualTime) return 0;
        uint256 timeElapsed = block.timestamp - loan.lastAccrualTime;
        return LoanMath.calculateInterest(
            loan.borrowedAmount,
            loan.interestRateAtOrigination,
            timeElapsed
        );
    }

    function getOutstandingDebt(Loan memory loan) internal view returns (uint256) {
        return loan.borrowedAmount + loan.accruedInterest + accrueInterest(loan);
    }
}
