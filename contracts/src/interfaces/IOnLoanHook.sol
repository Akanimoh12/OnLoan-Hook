// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LendingPoolState} from "../types/PoolTypes.sol";
import {Loan} from "../types/LoanTypes.sol";

interface IOnLoanHook {
    function liquidateLoan(address borrower) external;
    function getPoolLendingState(PoolId poolId) external view returns (LendingPoolState memory);
    function getLoan(address borrower) external view returns (Loan memory);
    function getHealthFactor(address borrower) external view returns (uint256);
    function isOnLoanPool(PoolId poolId) external view returns (bool);
    function setLendingPool(address _lendingPool) external;
    function setLoanManager(address _loanManager) external;
    function setCollateralManager(address _collateralManager) external;
    function setLiquidationEngine(address _liquidationEngine) external;
    function setPriceOracle(address _priceOracle) external;
}
