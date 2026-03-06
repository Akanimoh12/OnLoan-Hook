// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Loan} from "../types/LoanTypes.sol";

interface ILoanManager {
    function setHook(address _hook) external;
    function setLiquidationEngine(address _engine) external;
    function createLoan(
        address borrower,
        PoolId poolId,
        address collateralToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 duration
    ) external returns (Loan memory);
    function accrueInterest(address borrower) external;
    function repay(address borrower, uint256 amount) external returns (uint256 remaining);
    function markLoanLiquidated(address borrower) external;
    function getLoan(address borrower) external view returns (Loan memory);
    function getOutstandingDebt(address borrower) external view returns (uint256);
    function getHealthFactor(address borrower) external view returns (uint256);
    function isLoanActive(address borrower) external view returns (bool);
    function isLoanExpired(address borrower) external view returns (bool);
    function getActiveBorrowerCount() external view returns (uint256);
    function getActiveBorrowers() external view returns (address[] memory);
    function getBorrowerPool(address borrower) external view returns (PoolId);
}
