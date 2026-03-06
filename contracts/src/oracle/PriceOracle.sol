// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OracleAdapter} from "./OracleAdapter.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {Events} from "../libraries/Events.sol";

contract PriceOracle is OracleAdapter, IPriceOracle, Ownable {
    mapping(address => uint256) internal prices;
    mapping(address => uint256) internal lastUpdated;
    mapping(address => uint8) internal _tokenDecimals;
    uint256 public stalePriceThreshold;

    error StalePrice(address token);
    error ArrayLengthMismatch();
    error ZeroPriceNotAllowed();

    constructor(uint256 _stalePriceThreshold) Ownable(msg.sender) {
        stalePriceThreshold = _stalePriceThreshold;
    }

    function setPrice(address token, uint256 priceUSD) external onlyOwner {
        if (priceUSD == 0) revert ZeroPriceNotAllowed();
        uint256 oldPrice = prices[token];
        prices[token] = priceUSD;
        lastUpdated[token] = block.timestamp;
        emit Events.PriceUpdated(token, oldPrice, priceUSD, block.timestamp);
    }

    function setBatchPrices(
        address[] calldata tokens,
        uint256[] calldata _prices
    ) external onlyOwner {
        if (tokens.length != _prices.length) revert ArrayLengthMismatch();
        for (uint256 i; i < tokens.length; ++i) {
            if (_prices[i] == 0) revert ZeroPriceNotAllowed();
            uint256 oldPrice = prices[tokens[i]];
            prices[tokens[i]] = _prices[i];
            lastUpdated[tokens[i]] = block.timestamp;
            emit Events.PriceUpdated(tokens[i], oldPrice, _prices[i], block.timestamp);
        }
    }

    function setTokenDecimals(address token, uint8 decimals) external onlyOwner {
        _tokenDecimals[token] = decimals;
    }

    function setStalePriceThreshold(uint256 threshold) external onlyOwner {
        stalePriceThreshold = threshold;
    }

    function getPrice(address token) external view override(OracleAdapter, IPriceOracle) returns (uint256) {
        if (block.timestamp - lastUpdated[token] > stalePriceThreshold) {
            revert StalePrice(token);
        }
        return prices[token];
    }

    function getDecimals(address token) external view override(OracleAdapter, IPriceOracle) returns (uint8) {
        return _tokenDecimals[token];
    }

    function isPriceStale(address token) external view override(OracleAdapter, IPriceOracle) returns (bool) {
        return block.timestamp - lastUpdated[token] > stalePriceThreshold;
    }
}
