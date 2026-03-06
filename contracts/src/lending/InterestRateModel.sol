// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {InterestRateConfig} from "../types/PoolTypes.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {InvalidRateParams, NotAuthorized} from "../types/Errors.sol";

contract InterestRateModel is IInterestRateModel, Ownable {
    uint256 internal constant BPS = 10_000;

    mapping(PoolId => InterestRateConfig) public rateConfigs;
    mapping(address => bool) public authorized;

    event RateConfigUpdated(PoolId indexed poolId, InterestRateConfig config);

    modifier onlyAuthorized() {
        if (msg.sender != owner() && !authorized[msg.sender]) revert NotAuthorized();
        _;
    }

    constructor() Ownable(msg.sender) {}

    function setAuthorized(address caller, bool status) external onlyOwner {
        authorized[caller] = status;
    }

    function setRateConfig(PoolId poolId, InterestRateConfig calldata config) external onlyAuthorized {
        if (config.baseRate == 0 || config.kinkRate == 0 || config.maxRate == 0) revert InvalidRateParams();
        if (config.baseRate >= config.kinkRate || config.kinkRate >= config.maxRate) revert InvalidRateParams();
        if (config.kinkUtilization < 1000 || config.kinkUtilization > 9500) revert InvalidRateParams();
        rateConfigs[poolId] = config;
        emit RateConfigUpdated(poolId, config);
    }

    function getInterestRate(PoolId poolId, uint256 utilization) public view returns (uint256) {
        InterestRateConfig storage config = rateConfigs[poolId];
        if (utilization <= config.kinkUtilization) {
            return config.baseRate + (utilization * (config.kinkRate - config.baseRate)) / config.kinkUtilization;
        }
        return config.kinkRate
            + ((utilization - config.kinkUtilization) * (config.maxRate - config.kinkRate))
                / (BPS - config.kinkUtilization);
    }

    function getUtilizationRate(uint256 totalDeposited, uint256 totalBorrowed) public pure returns (uint256) {
        if (totalDeposited == 0) return 0;
        uint256 utilization = (totalBorrowed * BPS) / totalDeposited;
        return utilization > BPS ? BPS : utilization;
    }

    function getBorrowRate(
        PoolId poolId,
        uint256 totalDeposited,
        uint256 totalBorrowed
    ) external view returns (uint256) {
        uint256 utilization = getUtilizationRate(totalDeposited, totalBorrowed);
        return getInterestRate(poolId, utilization);
    }

    function getSupplyRate(
        PoolId poolId,
        uint256 totalDeposited,
        uint256 totalBorrowed,
        uint256 protocolFeeBps
    ) external view returns (uint256) {
        uint256 utilization = getUtilizationRate(totalDeposited, totalBorrowed);
        uint256 borrowRate = getInterestRate(poolId, utilization);
        return (borrowRate * utilization * (BPS - protocolFeeBps)) / (BPS * BPS);
    }

    function getRateConfig(PoolId poolId) external view returns (InterestRateConfig memory) {
        return rateConfigs[poolId];
    }
}
