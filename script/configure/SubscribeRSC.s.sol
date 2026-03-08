// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";

import {LiquidationRSC} from "../../contracts/src/reactive/LiquidationRSC.sol";
import {CrossChainCollateralWatcher} from "../../contracts/src/reactive/CrossChainCollateralWatcher.sol";

/// @title SubscribeRSC
/// @notice Post-deployment configuration for RSC event subscriptions.
///         Use this script to add monitored borrowers, chains, or update
///         collateral configurations after initial deployment.
///
/// Usage:
///   forge script script/configure/SubscribeRSC.s.sol \
///     --rpc-url $REACTIVE_RPC_URL \
///     --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast
contract SubscribeRSC is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address liquidationRSCAddr = vm.envAddress("LIQUIDATION_RSC_ADDRESS");
        address watcherAddr = vm.envAddress("CROSS_CHAIN_WATCHER_ADDRESS");

        LiquidationRSC liquidationRSC = LiquidationRSC(payable(liquidationRSCAddr));
        CrossChainCollateralWatcher watcher = CrossChainCollateralWatcher(payable(watcherAddr));

        vm.startBroadcast(deployerKey);

        // ─── Update LiquidationRSC config ─────────────────────────────
        // Example: Add new collateral token
        // liquidationRSC.setCollateralConfig(newTokenAddress, 7500, 18);

        // Example: Adjust rate limiting
        // liquidationRSC.setLiquidationCooldown(3 minutes);
        // liquidationRSC.setGracePeriod(1 minutes);

        // ─── Configure CrossChainCollateralWatcher ────────────────────
        // Example: Add Ethereum mainnet WETH monitoring
        // watcher.addMonitoredChain(1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        // Example: Monitor specific borrowers
        // watcher.setMonitoredBorrower(borrowerAddress, true);

        vm.stopBroadcast();

        console.log("RSC configuration updated");
    }
}
