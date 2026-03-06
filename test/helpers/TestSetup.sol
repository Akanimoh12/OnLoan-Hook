// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

import {MockERC20} from "./MockERC20.sol";
import {PriceOracle} from "../../contracts/src/oracle/PriceOracle.sol";
import {InterestRateModel} from "../../contracts/src/lending/InterestRateModel.sol";
import {LendingReceipt6909} from "../../contracts/src/tokens/LendingReceipt6909.sol";
import {CollateralManager} from "../../contracts/src/lending/CollateralManager.sol";
import {LendingPool} from "../../contracts/src/lending/LendingPool.sol";
import {LoanManager} from "../../contracts/src/lending/LoanManager.sol";
import {LiquidationEngine} from "../../contracts/src/liquidation/LiquidationEngine.sol";
import {CollateralInfo} from "../../contracts/src/types/LoanTypes.sol";
import {PoolConfig, InterestRateConfig} from "../../contracts/src/types/PoolTypes.sol";

abstract contract TestSetup is Test {
    MockERC20 public usdc;
    MockERC20 public weth;
    MockERC20 public wbtc;

    PriceOracle public priceOracle;
    InterestRateModel public interestRateModel;
    LendingReceipt6909 public receiptToken;
    CollateralManager public collateralManager;
    LendingPool public lendingPool;
    LoanManager public loanManager;
    LiquidationEngine public liquidationEngine;

    address public hookAddress;
    address public lender1;
    address public lender2;
    address public borrower1;
    address public borrower2;
    address public liquidator;
    address public deployer;

    PoolId public poolId;

    uint256 constant PRECISION = 1e18;
    uint256 constant BPS = 10_000;

    function setUp() public virtual {
        deployer = address(this);
        hookAddress = makeAddr("hook");
        lender1 = makeAddr("lender1");
        lender2 = makeAddr("lender2");
        borrower1 = makeAddr("borrower1");
        borrower2 = makeAddr("borrower2");
        liquidator = makeAddr("liquidator");

        vm.label(hookAddress, "Hook");
        vm.label(lender1, "Lender1");
        vm.label(lender2, "Lender2");
        vm.label(borrower1, "Borrower1");
        vm.label(borrower2, "Borrower2");
        vm.label(liquidator, "Liquidator");

        _deployTokens();
        _deployProtocol();
        _setupAuthorization();
        _setupOracle();
        _setupCollateral();
        _initializePool();
        _mintTokens();
    }

    function _deployTokens() internal {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        vm.label(address(usdc), "USDC");
        vm.label(address(weth), "WETH");
        vm.label(address(wbtc), "WBTC");
    }

    function _deployProtocol() internal {
        priceOracle = new PriceOracle(1 hours);
        interestRateModel = new InterestRateModel();
        receiptToken = new LendingReceipt6909(address(this));
        collateralManager = new CollateralManager(address(priceOracle));
        lendingPool = new LendingPool(address(receiptToken), address(interestRateModel));
        loanManager = new LoanManager(address(lendingPool), address(collateralManager), address(priceOracle));
        liquidationEngine = new LiquidationEngine(
            address(loanManager), address(collateralManager), address(lendingPool), address(priceOracle)
        );

        vm.label(address(priceOracle), "PriceOracle");
        vm.label(address(interestRateModel), "InterestRateModel");
        vm.label(address(receiptToken), "ReceiptToken");
        vm.label(address(collateralManager), "CollateralManager");
        vm.label(address(lendingPool), "LendingPool");
        vm.label(address(loanManager), "LoanManager");
        vm.label(address(liquidationEngine), "LiquidationEngine");
    }

    function _setupAuthorization() internal {
        lendingPool.setHook(hookAddress);
        lendingPool.setAuthorized(address(loanManager), true);
        lendingPool.setAuthorized(address(liquidationEngine), true);

        interestRateModel.setAuthorized(address(lendingPool), true);

        receiptToken.setAuthorized(address(lendingPool), true);

        collateralManager.setAuthorized(address(loanManager), true);
        collateralManager.setAuthorized(address(liquidationEngine), true);

        loanManager.setHook(hookAddress);
        loanManager.setLiquidationEngine(address(liquidationEngine));

        liquidationEngine.setAuthorizedLiquidator(liquidator, true);
    }

    function _setupOracle() internal {
        priceOracle.setTokenDecimals(address(weth), 18);
        priceOracle.setTokenDecimals(address(wbtc), 8);
        priceOracle.setTokenDecimals(address(usdc), 6);

        priceOracle.setPrice(address(weth), 3000e18);
        priceOracle.setPrice(address(wbtc), 60000e18);
        priceOracle.setPrice(address(usdc), 1e18);
    }

    function _setupCollateral() internal {
        collateralManager.addSupportedCollateral(
            address(weth),
            CollateralInfo({
                token: address(weth),
                isSupported: true,
                liquidationThreshold: 8000,
                maxLTV: 7500,
                liquidationBonus: 500
            })
        );

        collateralManager.addSupportedCollateral(
            address(wbtc),
            CollateralInfo({
                token: address(wbtc),
                isSupported: true,
                liquidationThreshold: 8000,
                maxLTV: 7000,
                liquidationBonus: 500
            })
        );
    }

    function _initializePool() internal {
        poolId = PoolId.wrap(bytes32(uint256(1)));

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

        vm.prank(hookAddress);
        lendingPool.initializePool(poolId, config);
    }

    function _mintTokens() internal {
        usdc.mint(lender1, 100_000e6);
        usdc.mint(lender2, 100_000e6);
        usdc.mint(borrower1, 10_000e6);
        usdc.mint(borrower2, 10_000e6);

        weth.mint(borrower1, 100 ether);
        weth.mint(borrower2, 100 ether);
        wbtc.mint(borrower1, 10e8);
        wbtc.mint(borrower2, 10e8);

        vm.prank(borrower1);
        weth.approve(address(collateralManager), type(uint256).max);
        vm.prank(borrower1);
        wbtc.approve(address(collateralManager), type(uint256).max);
        vm.prank(borrower2);
        weth.approve(address(collateralManager), type(uint256).max);
        vm.prank(borrower2);
        wbtc.approve(address(collateralManager), type(uint256).max);
    }

    function _depositToPool(address lender, uint256 amount) internal returns (uint256 shares) {
        vm.prank(hookAddress);
        shares = lendingPool.deposit(poolId, lender, amount);
    }

    function _depositCollateral(address borrower, address token, uint256 amount) internal {
        vm.prank(borrower);
        collateralManager.depositCollateral(borrower, token, amount);
    }

    function _createLoan(
        address borrower,
        address collateralToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 duration
    ) internal {
        vm.prank(hookAddress);
        loanManager.createLoan(borrower, poolId, collateralToken, collateralAmount, borrowAmount, duration);
    }

    function _repayLoan(address borrower, uint256 amount) internal returns (uint256 remaining) {
        vm.prank(hookAddress);
        remaining = loanManager.repay(borrower, amount);
    }
}
