// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LendingPoolState, PoolConfig} from "../types/PoolTypes.sol";
import {LenderPosition} from "../types/LoanTypes.sol";
import {LoanMath} from "../libraries/LoanMath.sol";
import {Events} from "../libraries/Events.sol";
import {LendingReceipt6909} from "../tokens/LendingReceipt6909.sol";
import {InterestRateModel} from "./InterestRateModel.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {ZeroAmount, PoolNotActive, InsufficientPoolLiquidity, InsufficientShares, CooldownNotElapsed, NotAuthorized} from "../types/Errors.sol";

contract LendingPool is ILendingPool, Ownable, ReentrancyGuard {
    mapping(PoolId => LendingPoolState) public pools;
    mapping(PoolId => mapping(address => LenderPosition)) public lenderPositions;
    mapping(PoolId => PoolConfig) public poolConfigs;

    LendingReceipt6909 public receiptToken;
    InterestRateModel public interestRateModel;
    address public hook;
    mapping(address => bool) public authorized;

    error PoolAlreadyInitialized();
    error NotHook();

    modifier onlyHook() {
        if (msg.sender != hook) revert NotHook();
        _;
    }

    modifier onlyHookOrAuthorized() {
        if (msg.sender != hook && !authorized[msg.sender] && msg.sender != owner()) revert NotAuthorized();
        _;
    }

    constructor(address _receiptToken, address _interestRateModel) Ownable(msg.sender) {
        receiptToken = LendingReceipt6909(_receiptToken);
        interestRateModel = InterestRateModel(_interestRateModel);
    }

    function setHook(address _hook) external onlyOwner {
        hook = _hook;
    }

    function setAuthorized(address caller, bool status) external onlyOwner {
        authorized[caller] = status;
    }

    function initializePool(PoolId poolId, PoolConfig calldata config) external onlyHookOrAuthorized {
        if (pools[poolId].lastUpdateTime != 0) revert PoolAlreadyInitialized();
        poolConfigs[poolId] = config;
        pools[poolId] = LendingPoolState({
            totalDeposited: 0,
            totalBorrowed: 0,
            totalShares: 0,
            lastUpdateTime: block.timestamp,
            accumulatedProtocolFees: 0
        });
        interestRateModel.setRateConfig(poolId, config.interestRateConfig);
        emit Events.LendingPoolCreated(poolId, config.interestRateConfig.baseRate, 0);
    }

    function deposit(PoolId poolId, address lender, uint256 amount) external onlyHookOrAuthorized nonReentrant returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();
        if (!poolConfigs[poolId].isActive) revert PoolNotActive();

        LendingPoolState storage pool = pools[poolId];
        shares = LoanMath.calculateShares(amount, pool.totalShares, pool.totalDeposited);

        pool.totalDeposited += amount;
        pool.totalShares += shares;
        pool.lastUpdateTime = block.timestamp;

        LenderPosition storage pos = lenderPositions[poolId][lender];
        pos.deposited += amount;
        pos.shares += shares;
        pos.lastDepositTime = block.timestamp;

        uint256 tokenId = receiptToken.poolIdToTokenId(poolId);
        receiptToken.mint(lender, tokenId, shares);

        emit Events.LenderDeposited(poolId, lender, amount, shares);
    }

    function withdraw(PoolId poolId, address lender, uint256 shares) external onlyHookOrAuthorized nonReentrant returns (uint256 amount) {
        if (shares == 0) revert ZeroAmount();

        LenderPosition storage pos = lenderPositions[poolId][lender];
        if (pos.shares < shares) revert InsufficientShares(pos.shares, shares);

        PoolConfig storage config = poolConfigs[poolId];
        if (block.timestamp < pos.lastDepositTime + config.withdrawalCooldown) {
            revert CooldownNotElapsed(pos.lastDepositTime + config.withdrawalCooldown - block.timestamp);
        }

        LendingPoolState storage pool = pools[poolId];
        amount = LoanMath.calculateAmountFromShares(shares, pool.totalShares, pool.totalDeposited);

        uint256 available = pool.totalDeposited - pool.totalBorrowed;
        if (amount > available) revert InsufficientPoolLiquidity(available, amount);

        pool.totalDeposited -= amount;
        pool.totalShares -= shares;
        pool.lastUpdateTime = block.timestamp;

        pos.deposited = pos.deposited > amount ? pos.deposited - amount : 0;
        pos.shares -= shares;

        uint256 tokenId = receiptToken.poolIdToTokenId(poolId);
        receiptToken.burn(lender, tokenId, shares);

        emit Events.LenderWithdrew(poolId, lender, amount, shares);
    }

    function recordBorrow(PoolId poolId, uint256 amount) external onlyHookOrAuthorized {
        LendingPoolState storage pool = pools[poolId];
        uint256 available = pool.totalDeposited - pool.totalBorrowed;
        if (amount > available) revert InsufficientPoolLiquidity(available, amount);
        pool.totalBorrowed += amount;
        pool.lastUpdateTime = block.timestamp;
    }

    function recordRepayment(PoolId poolId, uint256 principal, uint256 interest) external onlyHookOrAuthorized {
        LendingPoolState storage pool = pools[poolId];
        pool.totalBorrowed -= principal;

        PoolConfig storage config = poolConfigs[poolId];
        uint256 protocolFee = (interest * config.protocolFeeRate) / LoanMath.BPS;
        uint256 lenderInterest = interest - protocolFee;

        pool.accumulatedProtocolFees += protocolFee;
        pool.totalDeposited += lenderInterest;
        pool.lastUpdateTime = block.timestamp;

        emit Events.InterestDistributed(poolId, interest, protocolFee);
    }

    function getAvailableLiquidity(PoolId poolId) external view returns (uint256) {
        LendingPoolState storage pool = pools[poolId];
        if (pool.totalBorrowed >= pool.totalDeposited) return 0;
        return pool.totalDeposited - pool.totalBorrowed;
    }

    function getUtilizationRate(PoolId poolId) external view returns (uint256) {
        LendingPoolState storage pool = pools[poolId];
        return interestRateModel.getUtilizationRate(pool.totalDeposited, pool.totalBorrowed);
    }

    function getCurrentInterestRate(PoolId poolId) external view returns (uint256) {
        LendingPoolState storage pool = pools[poolId];
        return interestRateModel.getBorrowRate(poolId, pool.totalDeposited, pool.totalBorrowed);
    }

    function getLenderShares(PoolId poolId, address lender) external view returns (uint256) {
        return lenderPositions[poolId][lender].shares;
    }

    function getPoolState(PoolId poolId) external view returns (LendingPoolState memory) {
        return pools[poolId];
    }

    function getPoolConfig(PoolId poolId) external view returns (PoolConfig memory) {
        return poolConfigs[poolId];
    }

    function canWithdraw(PoolId poolId, address lender) external view returns (bool) {
        LenderPosition storage pos = lenderPositions[poolId][lender];
        if (pos.shares == 0) return false;
        return block.timestamp >= pos.lastDepositTime + poolConfigs[poolId].withdrawalCooldown;
    }
}
