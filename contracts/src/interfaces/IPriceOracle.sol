// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IPriceOracle {
    function setPrice(address token, uint256 priceUSD) external;
    function setBatchPrices(address[] calldata tokens, uint256[] calldata prices) external;
    function setTokenDecimals(address token, uint8 decimals) external;
    function setStalePriceThreshold(uint256 threshold) external;
    function getPrice(address token) external view returns (uint256);
    function getDecimals(address token) external view returns (uint8);
    function isPriceStale(address token) external view returns (bool);
}
