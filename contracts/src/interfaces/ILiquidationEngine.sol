// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILiquidationEngine {
    function setAuthorizedLiquidator(address liquidator, bool authorized) external;
    function liquidateLoan(address borrower) external;
    function isLiquidatable(address borrower) external view returns (bool);
    function getLiquidationInfo(address borrower)
        external
        view
        returns (uint256 healthFactor, uint256 debtUSD, uint256 collateralUSD, uint256 bonus);
    function authorizedLiquidators(address liquidator) external view returns (bool);
}
