// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LendingPoolState, PoolConfig, InterestRateConfig} from "../types/PoolTypes.sol";
import {Loan} from "../types/LoanTypes.sol";
import {Events} from "../libraries/Events.sol";
import {LoanMath} from "../libraries/LoanMath.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {ILiquidationEngine} from "../interfaces/ILiquidationEngine.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {LendingReceipt6909} from "../tokens/LendingReceipt6909.sol";
import {HookPermissions} from "./HookPermissions.sol";
import {CooldownNotElapsed, InsufficientPoolLiquidity, LoanNotActive} from "../types/Errors.sol";

contract OnLoanHook is IHooks, HookPermissions, Ownable, ReentrancyGuard {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeERC20 for IERC20;

    IPoolManager public immutable poolManager;
    ILendingPool public lendingPool;
    ILoanManager public loanManager;
    ICollateralManager public collateralManager;
    ILiquidationEngine public liquidationEngine;
    IPriceOracle public priceOracle;
    LendingReceipt6909 public receiptToken;

    mapping(PoolId => bool) public isOnLoanPool;
    mapping(PoolId => address) public poolDepositToken;

    bytes1 private constant BORROW_FLAG = 0x01;
    bytes1 private constant REPAY_FLAG = 0x02;

    error NotPoolManager();
    error NotOnLoanPool();
    error PoolAlreadyRegistered();

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    modifier onlyOnLoanPool(PoolKey calldata key) {
        if (!isOnLoanPool[key.toId()]) revert NotOnLoanPool();
        _;
    }

    constructor(
        IPoolManager _poolManager,
        address _lendingPool,
        address _loanManager,
        address _collateralManager,
        address _liquidationEngine,
        address _priceOracle,
        address _receiptToken,
        address _owner
    ) Ownable(_owner) {
        poolManager = _poolManager;
        lendingPool = ILendingPool(_lendingPool);
        loanManager = ILoanManager(_loanManager);
        collateralManager = ICollateralManager(_collateralManager);
        liquidationEngine = ILiquidationEngine(_liquidationEngine);
        priceOracle = IPriceOracle(_priceOracle);
        receiptToken = LendingReceipt6909(_receiptToken);
        Hooks.validateHookPermissions(IHooks(address(this)), getHookPermissions());
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) external onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();
        if (isOnLoanPool[poolId]) revert PoolAlreadyRegistered();
        isOnLoanPool[poolId] = true;
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24
    ) external onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();

        PoolConfig memory config = PoolConfig({
            interestRateConfig: InterestRateConfig({
                baseRate: 200,
                kinkRate: 1000,
                maxRate: 2000,
                kinkUtilization: 8000
            }),
            protocolFeeRate: 1000,
            minLoanDuration: 1 days,
            maxLoanDuration: 365 days,
            withdrawalCooldown: 1 days,
            isActive: true
        });

        lendingPool.initializePool(poolId, config);
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external onlyPoolManager onlyOnLoanPool(key) returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) external onlyPoolManager onlyOnLoanPool(key) returns (bytes4, BalanceDelta) {
        _processDeposit(key.toId(), sender, delta);
        return (IHooks.afterAddLiquidity.selector, toBalanceDelta(0, 0));
    }

    function _processDeposit(PoolId poolId, address sender, BalanceDelta delta) internal {
        int128 amt0 = delta.amount0();
        uint256 depositAmount;
        if (amt0 > 0) {
            depositAmount = uint256(uint128(amt0));
        } else {
            int128 amt1 = delta.amount1();
            if (amt1 > 0) {
                depositAmount = uint256(uint128(amt1));
            }
        }
        if (depositAmount > 0) {
            lendingPool.deposit(poolId, sender, depositAmount);
        }
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external onlyPoolManager onlyOnLoanPool(key) returns (bytes4) {
        PoolId poolId = key.toId();
        if (!lendingPool.canWithdraw(poolId, sender)) {
            revert CooldownNotElapsed(0);
        }
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) external onlyPoolManager onlyOnLoanPool(key) returns (bytes4, BalanceDelta) {
        _processWithdrawal(key.toId(), sender, delta);
        return (IHooks.afterRemoveLiquidity.selector, toBalanceDelta(0, 0));
    }

    function _processWithdrawal(PoolId poolId, address sender, BalanceDelta delta) internal {
        uint256 lenderShares = lendingPool.getLenderShares(poolId, sender);
        if (lenderShares == 0) return;

        int128 amt0 = delta.amount0();
        uint256 withdrawAmount;
        if (amt0 < 0) {
            withdrawAmount = uint256(uint128(-amt0));
        } else {
            int128 amt1 = delta.amount1();
            if (amt1 < 0) {
                withdrawAmount = uint256(uint128(-amt1));
            }
        }

        if (withdrawAmount > 0) {
            LendingPoolState memory state = lendingPool.getPoolState(poolId);
            uint256 sharesToWithdraw = LoanMath.calculateShares(withdrawAmount, state.totalShares, state.totalDeposited);
            if (sharesToWithdraw > lenderShares) {
                sharesToWithdraw = lenderShares;
            }
            if (sharesToWithdraw > 0) {
                lendingPool.withdraw(poolId, sender, sharesToWithdraw);
            }
        }
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata hookData
    ) external onlyPoolManager onlyOnLoanPool(key) returns (bytes4, BeforeSwapDelta, uint24) {
        if (hookData.length > 0 && hookData[0] == BORROW_FLAG) {
            (
                ,
                ,
                ,
                ,
                uint256 borrowAmount,

            ) = abi.decode(hookData, (bytes1, address, address, uint256, uint256, uint256));

            PoolId poolId = key.toId();

            uint256 available = lendingPool.getAvailableLiquidity(poolId);
            if (borrowAmount > available) revert InsufficientPoolLiquidity(available, borrowAmount);
        }

        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata hookData
    ) external onlyPoolManager onlyOnLoanPool(key) returns (bytes4, int128) {
        if (hookData.length > 0 && hookData[0] == BORROW_FLAG) {
            (
                ,
                address borrower,
                address collateralToken,
                uint256 collateralAmount,
                uint256 borrowAmount,
                uint256 duration
            ) = abi.decode(hookData, (bytes1, address, address, uint256, uint256, uint256));

            PoolId poolId = key.toId();
            loanManager.createLoan(borrower, poolId, collateralToken, collateralAmount, borrowAmount, duration);
        }

        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(
        address,
        PoolKey calldata key,
        uint256,
        uint256,
        bytes calldata hookData
    ) external onlyPoolManager onlyOnLoanPool(key) returns (bytes4) {
        if (hookData.length > 0 && hookData[0] == REPAY_FLAG) {
            (, address borrower) = abi.decode(hookData, (bytes1, address));
            if (!loanManager.isLoanActive(borrower)) revert LoanNotActive(borrower);
        }
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(
        address,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external onlyPoolManager onlyOnLoanPool(key) returns (bytes4) {
        if (hookData.length > 0 && hookData[0] == REPAY_FLAG) {
            (, address borrower) = abi.decode(hookData, (bytes1, address));
            uint256 repayAmount = amount0 > 0 ? amount0 : amount1;
            loanManager.repay(borrower, repayAmount);
        }
        return IHooks.afterDonate.selector;
    }

    function liquidateLoan(address borrower) external {
        liquidationEngine.liquidateLoan(borrower);
    }

    // --- Direct deposit/withdraw (bypasses V4 modifyLiquidity) ---

    function setPoolDepositToken(PoolId poolId, address token) external onlyOwner {
        poolDepositToken[poolId] = token;
    }

    function depositDirect(PoolId poolId, uint256 amount) external nonReentrant returns (uint256 shares) {
        address token = poolDepositToken[poolId];
        require(token != address(0), "Pool deposit token not set");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        shares = lendingPool.deposit(poolId, msg.sender, amount);
    }

    function withdrawDirect(PoolId poolId, uint256 shareAmount) external nonReentrant returns (uint256 amount) {
        address token = poolDepositToken[poolId];
        require(token != address(0), "Pool deposit token not set");

        amount = lendingPool.withdraw(poolId, msg.sender, shareAmount);
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    // --- View functions ---

    function getPoolLendingState(PoolId poolId) external view returns (LendingPoolState memory) {
        return lendingPool.getPoolState(poolId);
    }

    function getLoan(address borrower) external view returns (Loan memory) {
        return loanManager.getLoan(borrower);
    }

    function getHealthFactor(address borrower) external view returns (uint256) {
        return loanManager.getHealthFactor(borrower);
    }

    function setLendingPool(address _lendingPool) external onlyOwner {
        lendingPool = ILendingPool(_lendingPool);
    }

    function setLoanManager(address _loanManager) external onlyOwner {
        loanManager = ILoanManager(_loanManager);
    }

    function setCollateralManager(address _collateralManager) external onlyOwner {
        collateralManager = ICollateralManager(_collateralManager);
    }

    function setLiquidationEngine(address _liquidationEngine) external onlyOwner {
        liquidationEngine = ILiquidationEngine(_liquidationEngine);
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
    }
}
