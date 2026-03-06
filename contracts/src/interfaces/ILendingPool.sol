// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LendingPoolState, PoolConfig} from "../types/PoolTypes.sol";
import {LenderPosition} from "../types/LoanTypes.sol";

interface ILendingPool {
    function setHook(address _hook) external;
    function setAuthorized(address caller, bool status) external;
    function initializePool(PoolId poolId, PoolConfig calldata config) external;
    function deposit(PoolId poolId, address lender, uint256 amount) external returns (uint256 shares);
    function withdraw(PoolId poolId, address lender, uint256 shares) external returns (uint256 amount);
    function recordBorrow(PoolId poolId, uint256 amount) external;
    function recordRepayment(PoolId poolId, uint256 principal, uint256 interest) external;
    function getAvailableLiquidity(PoolId poolId) external view returns (uint256);
    function getUtilizationRate(PoolId poolId) external view returns (uint256);
    function getCurrentInterestRate(PoolId poolId) external view returns (uint256);
    function getLenderShares(PoolId poolId, address lender) external view returns (uint256);
    function getPoolState(PoolId poolId) external view returns (LendingPoolState memory);
    function getPoolConfig(PoolId poolId) external view returns (PoolConfig memory);
    function canWithdraw(PoolId poolId, address lender) external view returns (bool);
}
