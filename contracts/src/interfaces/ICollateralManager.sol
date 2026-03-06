// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {CollateralInfo} from "../types/LoanTypes.sol";

interface ICollateralManager {
    function setAuthorized(address caller, bool status) external;
    function addSupportedCollateral(address token, CollateralInfo calldata info) external;
    function removeSupportedCollateral(address token) external;
    function depositCollateral(address borrower, address token, uint256 amount) external;
    function withdrawCollateral(address borrower, address token, uint256 amount) external;
    function lockCollateral(address borrower, address token, uint256 amount) external;
    function unlockCollateral(address borrower, address token, uint256 amount) external;
    function seizeCollateral(address borrower, address token, uint256 amount) external;
    function getCollateralValueUSD(address borrower, address token) external view returns (uint256);
    function getTotalCollateralValueUSD(address borrower) external view returns (uint256);
    function getAvailableCollateral(address borrower, address token) external view returns (uint256);
    function isCollateralSufficient(address borrower, address token, uint256 borrowAmountUSD) external view returns (bool);
    function getCollateralInfo(address token) external view returns (CollateralInfo memory);
    function getCollateralTokenCount() external view returns (uint256);
    function collateralBalances(address borrower, address token) external view returns (uint256);
    function lockedCollateral(address borrower, address token) external view returns (uint256);
}
