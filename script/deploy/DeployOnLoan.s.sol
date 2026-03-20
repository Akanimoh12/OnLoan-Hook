// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {PriceOracle} from "../../contracts/src/oracle/PriceOracle.sol";
import {InterestRateModel} from "../../contracts/src/lending/InterestRateModel.sol";
import {LendingReceipt6909} from "../../contracts/src/tokens/LendingReceipt6909.sol";
import {CollateralManager} from "../../contracts/src/lending/CollateralManager.sol";
import {LendingPool} from "../../contracts/src/lending/LendingPool.sol";
import {LoanManager} from "../../contracts/src/lending/LoanManager.sol";
import {LiquidationEngine} from "../../contracts/src/liquidation/LiquidationEngine.sol";
import {OnLoanHook} from "../../contracts/src/hook/OnLoanHook.sol";
import {CollateralInfo} from "../../contracts/src/types/LoanTypes.sol";
import {PoolConfig, InterestRateConfig} from "../../contracts/src/types/PoolTypes.sol";
import {HookMiner} from "../utils/HookMiner.s.sol";

contract DeployOnLoan is Script {
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    PriceOracle public priceOracle;
    InterestRateModel public interestRateModel;
    LendingReceipt6909 public receiptToken;
    CollateralManager public collateralManager;
    LendingPool public lendingPool;
    LoanManager public loanManager;
    LiquidationEngine public liquidationEngine;
    OnLoanHook public hook;

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address poolManagerAddr = vm.envAddress("POOL_MANAGER_ADDRESS");
        uint256 stalePriceThreshold = vm.envOr("STALE_PRICE_THRESHOLD", uint256(1 hours));

        address wethAddr = vm.envOr("WETH_ADDRESS", address(0));
        address wbtcAddr = vm.envOr("WBTC_ADDRESS", address(0));
        address rscLiquidator = vm.envOr("RSC_LIQUIDATOR_ADDRESS", address(0));

        console.log("Deployer:", deployer);
        console.log("PoolManager:", poolManagerAddr);
        console.log("---");

        vm.startBroadcast(deployerKey);

        priceOracle = new PriceOracle(stalePriceThreshold);
        console.log("PriceOracle:", address(priceOracle));

        interestRateModel = new InterestRateModel();
        console.log("InterestRateModel:", address(interestRateModel));

        receiptToken = new LendingReceipt6909(deployer);
        console.log("LendingReceipt6909:", address(receiptToken));

        collateralManager = new CollateralManager(address(priceOracle));
        console.log("CollateralManager:", address(collateralManager));

        lendingPool = new LendingPool(address(receiptToken), address(interestRateModel));
        console.log("LendingPool:", address(lendingPool));

        loanManager = new LoanManager(address(lendingPool), address(collateralManager), address(priceOracle));
        console.log("LoanManager:", address(loanManager));

        liquidationEngine = new LiquidationEngine(
            address(loanManager), address(collateralManager), address(lendingPool), address(priceOracle)
        );
        console.log("LiquidationEngine:", address(liquidationEngine));

        _deployHook(poolManagerAddr, deployer);

        _configureAuthorization();
        _initializePools();
        _configureCollateral(wethAddr, wbtcAddr);
        _configureLiquidator(rscLiquidator);

        vm.stopBroadcast();

        _writeAddresses();

        console.log("--- Deployment Complete ---");
    }

    function _deployHook(address poolManagerAddr, address deployer) internal {
        bytes memory constructorArgs = abi.encode(
            IPoolManager(poolManagerAddr),
            address(lendingPool),
            address(loanManager),
            address(collateralManager),
            address(liquidationEngine),
            address(priceOracle),
            address(receiptToken),
            deployer
        );

        (address hookAddr, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            HookMiner.REQUIRED_FLAGS,
            type(OnLoanHook).creationCode,
            constructorArgs
        );

        console.log("Mined hook address:", hookAddr);
        console.log("Salt:", vm.toString(salt));

        hook = new OnLoanHook{salt: salt}(
            IPoolManager(poolManagerAddr),
            address(lendingPool),
            address(loanManager),
            address(collateralManager),
            address(liquidationEngine),
            address(priceOracle),
            address(receiptToken),
            deployer
        );

        require(address(hook) == hookAddr, "Hook address mismatch");
        console.log("OnLoanHook:", address(hook));
        console.log("---");
    }

    function _configureAuthorization() internal {
        lendingPool.setHook(address(hook));
        lendingPool.setAuthorized(address(hook), true);
        lendingPool.setAuthorized(address(loanManager), true);
        lendingPool.setAuthorized(address(liquidationEngine), true);

        interestRateModel.setAuthorized(address(lendingPool), true);

        receiptToken.setAuthorized(address(lendingPool), true);

        collateralManager.setAuthorized(address(loanManager), true);
        collateralManager.setAuthorized(address(liquidationEngine), true);

        loanManager.setHook(address(hook));
        loanManager.setLiquidationEngine(address(liquidationEngine));

        // Configure deposit tokens for direct deposit/withdraw
        address usdcAddr = vm.envOr("USDC_ADDRESS", address(0));
        if (usdcAddr != address(0)) {
            hook.setPoolDepositToken(
                PoolId.wrap(bytes32(uint256(1))),
                usdcAddr
            );
            console.log("USDC deposit token configured for pool 1");
        }

        console.log("Authorization configured");
    }

    function _initializePools() internal {
        PoolConfig memory usdcConfig = PoolConfig({
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

        lendingPool.initializePool(PoolId.wrap(bytes32(uint256(1))), usdcConfig);
        console.log("USDC pool (ID=1) initialized");
    }

    function _configureCollateral(address wethAddr, address wbtcAddr) internal {
        if (wethAddr != address(0)) {
            priceOracle.setTokenDecimals(wethAddr, 18);
            priceOracle.setPrice(wethAddr, 3000e18);

            collateralManager.addSupportedCollateral(
                wethAddr,
                CollateralInfo({
                    token: wethAddr,
                    isSupported: true,
                    liquidationThreshold: 8000,
                    maxLTV: 7500,
                    liquidationBonus: 500
                })
            );
            console.log("WETH collateral configured:", wethAddr);
        }

        if (wbtcAddr != address(0)) {
            priceOracle.setTokenDecimals(wbtcAddr, 8);
            priceOracle.setPrice(wbtcAddr, 60000e18);

            collateralManager.addSupportedCollateral(
                wbtcAddr,
                CollateralInfo({
                    token: wbtcAddr,
                    isSupported: true,
                    liquidationThreshold: 8000,
                    maxLTV: 7000,
                    liquidationBonus: 500
                })
            );
            console.log("WBTC collateral configured:", wbtcAddr);
        }
    }

    function _configureLiquidator(address rscLiquidator) internal {
        if (rscLiquidator != address(0)) {
            liquidationEngine.setAuthorizedLiquidator(rscLiquidator, true);
            console.log("RSC liquidator authorized:", rscLiquidator);
        }
    }

    function _writeAddresses() internal {
        string memory json = "deployment";
        vm.serializeAddress(json, "priceOracle", address(priceOracle));
        vm.serializeAddress(json, "interestRateModel", address(interestRateModel));
        vm.serializeAddress(json, "receiptToken", address(receiptToken));
        vm.serializeAddress(json, "collateralManager", address(collateralManager));
        vm.serializeAddress(json, "lendingPool", address(lendingPool));
        vm.serializeAddress(json, "loanManager", address(loanManager));
        vm.serializeAddress(json, "liquidationEngine", address(liquidationEngine));
        string memory out = vm.serializeAddress(json, "onLoanHook", address(hook));
        vm.writeJson(out, "./deployments/addresses.json");
        console.log("Addresses written to deployments/addresses.json");
    }
}
