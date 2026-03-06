// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {InterestRateConfig} from "../types/PoolTypes.sol";

interface IInterestRateModel {
    function setRateConfig(PoolId poolId, InterestRateConfig calldata config) external;
    function setAuthorized(address caller, bool status) external;
    function getInterestRate(PoolId poolId, uint256 utilization) external view returns (uint256);
    function getUtilizationRate(uint256 totalDeposited, uint256 totalBorrowed) external pure returns (uint256);
    function getBorrowRate(PoolId poolId, uint256 totalDeposited, uint256 totalBorrowed) external view returns (uint256);
    function getSupplyRate(PoolId poolId, uint256 totalDeposited, uint256 totalBorrowed, uint256 protocolFeeBps) external view returns (uint256);
    function getRateConfig(PoolId poolId) external view returns (InterestRateConfig memory);
}
