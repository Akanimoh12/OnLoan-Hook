// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CollateralManager} from "../../contracts/src/lending/CollateralManager.sol";
import {LendingPool} from "../../contracts/src/lending/LendingPool.sol";
import {LiquidationEngine} from "../../contracts/src/liquidation/LiquidationEngine.sol";
import {PriceOracle} from "../../contracts/src/oracle/PriceOracle.sol";
import {CollateralInfo} from "../../contracts/src/types/LoanTypes.sol";

contract SetupLendingPool is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address collateralManagerAddr = vm.envAddress("COLLATERAL_MANAGER_ADDRESS");
        address lendingPoolAddr = vm.envAddress("LENDING_POOL_ADDRESS");
        address liquidationEngineAddr = vm.envAddress("LIQUIDATION_ENGINE_ADDRESS");
        address oracleAddr = vm.envAddress("PRICE_ORACLE_ADDRESS");

        CollateralManager cm = CollateralManager(collateralManagerAddr);
        PriceOracle oracle = PriceOracle(oracleAddr);
        LiquidationEngine le = LiquidationEngine(liquidationEngineAddr);

        vm.startBroadcast(deployerKey);

        address wethAddr = vm.envOr("WETH_ADDRESS", address(0));
        if (wethAddr != address(0)) {
            _setupCollateral(cm, oracle, wethAddr, 18, 3000e18, 8000, 7500, 500);
            console.log("WETH configured:", wethAddr);
        }

        address wbtcAddr = vm.envOr("WBTC_ADDRESS", address(0));
        if (wbtcAddr != address(0)) {
            _setupCollateral(cm, oracle, wbtcAddr, 8, 60000e18, 8000, 7000, 500);
            console.log("WBTC configured:", wbtcAddr);
        }

        address usdcAddr = vm.envOr("USDC_ADDRESS", address(0));
        if (usdcAddr != address(0)) {
            oracle.setTokenDecimals(usdcAddr, 6);
            oracle.setPrice(usdcAddr, 1e18);
            console.log("USDC price set:", usdcAddr);
        }

        address rscLiquidator = vm.envOr("RSC_LIQUIDATOR_ADDRESS", address(0));
        if (rscLiquidator != address(0)) {
            le.setAuthorizedLiquidator(rscLiquidator, true);
            console.log("RSC liquidator authorized:", rscLiquidator);
        }

        vm.stopBroadcast();

        console.log("--- Pool Setup Complete ---");
    }

    function _setupCollateral(
        CollateralManager cm,
        PriceOracle oracle,
        address token,
        uint8 decimals,
        uint256 price,
        uint256 liquidationThreshold,
        uint256 maxLTV,
        uint256 liquidationBonus
    ) internal {
        oracle.setTokenDecimals(token, decimals);
        oracle.setPrice(token, price);

        cm.addSupportedCollateral(
            token,
            CollateralInfo({
                token: token,
                isSupported: true,
                liquidationThreshold: liquidationThreshold,
                maxLTV: maxLTV,
                liquidationBonus: liquidationBonus
            })
        );
    }
}
