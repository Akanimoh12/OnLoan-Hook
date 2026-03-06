// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";

// TODO: Person B (Reactive Network engineer) will complete this script
// TODO: Import ReactiveMonitor, LiquidationRSC, CrossChainCollateralWatcher
// TODO: Deploy to Reactive Network (not Unichain)
//
// Required addresses from Unichain deployment:
//   - ONLOAN_HOOK_ADDRESS: Hook contract on Unichain
//   - PRICE_ORACLE_ADDRESS: PriceOracle on Unichain
//   - UNICHAIN_CHAIN_ID: Chain ID for event subscriptions
//
// Deployment steps:
//   1. Deploy LiquidationRSC with:
//      - Origin chain = Unichain
//      - Subscribed event = PriceUpdated(address,uint256,uint256)
//      - Callback target = OnLoanHook.liquidateLoan() on Unichain
//      - Health factor threshold = 1.2e18 (120%)
//
//   2. Deploy CrossChainCollateralWatcher with:
//      - Monitored chains = [Ethereum Mainnet, ...]
//      - Subscribed events = Transfer events on collateral tokens
//      - Callback target = CollateralManager on Unichain
//
//   3. Subscribe RSCs to appropriate event topics
//
// Usage:
//   forge script script/deploy/DeployReactiveMonitor.s.sol \
//     --rpc-url $REACTIVE_RPC_URL \
//     --private-key $DEPLOYER_PRIVATE_KEY \
//     --broadcast

contract DeployReactiveMonitor is Script {
    function run() external {
        // uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        // address hookAddress = vm.envAddress("ONLOAN_HOOK_ADDRESS");
        // address oracleAddress = vm.envAddress("PRICE_ORACLE_ADDRESS");

        // vm.startBroadcast(deployerKey);

        // TODO: Deploy LiquidationRSC
        // TODO: Deploy CrossChainCollateralWatcher
        // TODO: Register event subscriptions

        // vm.stopBroadcast();

        console.log("DeployReactiveMonitor: Not yet implemented");
        console.log("Waiting for Person B (Reactive Network engineer)");
    }
}
