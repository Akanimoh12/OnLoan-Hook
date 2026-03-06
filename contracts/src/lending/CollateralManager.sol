// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CollateralInfo} from "../types/LoanTypes.sol";
import {CollateralValuation} from "../libraries/CollateralValuation.sol";
import {HealthFactor} from "../libraries/HealthFactor.sol";
import {Events} from "../libraries/Events.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {UnsupportedCollateral, ZeroAmount, InsufficientCollateral, NotAuthorized} from "../types/Errors.sol";

contract CollateralManager is ICollateralManager, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(address => uint256)) public lockedCollateral;
    mapping(address => CollateralInfo) public supportedCollateral;
    address[] public collateralTokenList;
    IPriceOracle public priceOracle;
    mapping(address => bool) public authorized;

    modifier onlyAuthorized() {
        if (msg.sender != owner() && !authorized[msg.sender]) revert NotAuthorized();
        _;
    }

    constructor(address _priceOracle) Ownable(msg.sender) {
        priceOracle = IPriceOracle(_priceOracle);
    }

    function setAuthorized(address caller, bool status) external onlyOwner {
        authorized[caller] = status;
    }

    function addSupportedCollateral(address token, CollateralInfo calldata info) external onlyOwner {
        supportedCollateral[token] = info;
        collateralTokenList.push(token);
        emit Events.CollateralTokenAdded(token, info.maxLTV, info.liquidationThreshold);
    }

    function removeSupportedCollateral(address token) external onlyOwner {
        delete supportedCollateral[token];
        for (uint256 i; i < collateralTokenList.length; ++i) {
            if (collateralTokenList[i] == token) {
                collateralTokenList[i] = collateralTokenList[collateralTokenList.length - 1];
                collateralTokenList.pop();
                break;
            }
        }
        emit Events.CollateralTokenRemoved(token);
    }

    function depositCollateral(address borrower, address token, uint256 amount) external nonReentrant {
        if (!supportedCollateral[token].isSupported) revert UnsupportedCollateral(token);
        if (amount == 0) revert ZeroAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[borrower][token] += amount;
        emit Events.CollateralDeposited(borrower, token, amount);
    }

    function withdrawCollateral(address borrower, address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 available = collateralBalances[borrower][token] - lockedCollateral[borrower][token];
        if (amount > available) revert InsufficientCollateral(available, amount);
        collateralBalances[borrower][token] -= amount;
        IERC20(token).safeTransfer(borrower, amount);
        emit Events.CollateralWithdrawn(borrower, token, amount);
    }

    function lockCollateral(address borrower, address token, uint256 amount) external onlyAuthorized {
        uint256 available = collateralBalances[borrower][token] - lockedCollateral[borrower][token];
        if (available < amount) revert InsufficientCollateral(available, amount);
        lockedCollateral[borrower][token] += amount;
    }

    function unlockCollateral(address borrower, address token, uint256 amount) external onlyAuthorized {
        lockedCollateral[borrower][token] -= amount;
    }

    function seizeCollateral(address borrower, address token, uint256 amount) external onlyAuthorized {
        lockedCollateral[borrower][token] -= amount;
        collateralBalances[borrower][token] -= amount;
    }

    function getCollateralValueUSD(address borrower, address token) public view returns (uint256) {
        uint256 balance = collateralBalances[borrower][token];
        if (balance == 0) return 0;
        uint256 price = priceOracle.getPrice(token);
        uint8 decimals = priceOracle.getDecimals(token);
        return CollateralValuation.getCollateralValueUSD(balance, price, decimals);
    }

    function getTotalCollateralValueUSD(address borrower) public view returns (uint256) {
        uint256 total;
        for (uint256 i; i < collateralTokenList.length; ++i) {
            total += getCollateralValueUSD(borrower, collateralTokenList[i]);
        }
        return total;
    }

    function getAvailableCollateral(address borrower, address token) external view returns (uint256) {
        return collateralBalances[borrower][token] - lockedCollateral[borrower][token];
    }

    function isCollateralSufficient(
        address borrower,
        address token,
        uint256 borrowAmountUSD
    ) external view returns (bool) {
        uint256 collateralValue = getCollateralValueUSD(borrower, token);
        uint256 maxBorrowable = HealthFactor.calculateMaxBorrowable(
            collateralValue,
            supportedCollateral[token].maxLTV
        );
        return maxBorrowable >= borrowAmountUSD;
    }

    function getCollateralInfo(address token) external view returns (CollateralInfo memory) {
        return supportedCollateral[token];
    }

    function getCollateralTokenCount() external view returns (uint256) {
        return collateralTokenList.length;
    }
}
