// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

abstract contract OracleAdapter {
    function getPrice(address token) external view virtual returns (uint256);
    function getDecimals(address token) external view virtual returns (uint8);
    function isPriceStale(address token) external view virtual returns (bool);
}
