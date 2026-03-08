// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";

import {LiquidationRSC} from "../../contracts/src/reactive/LiquidationRSC.sol";
import {CrossChainCollateralWatcher} from "../../contracts/src/reactive/CrossChainCollateralWatcher.sol";

/// @title DeployReactiveMonitor
/// @notice Deploys OnLoan RSC infrastructure to the Reactive Network.
///
/// Required environment variables:
///   DEPLOYER_PRIVATE_KEY          — Deployer wallet
///   ONLOAN_HOOK_ADDRESS           — Hook contract on Unichain
///   PRICE_ORACLE_ADDRESS          — PriceOracle on Unichain
///   LOAN_MANAGER_ADDRESS          — LoanManager on Unichain
///   LIQUIDATION_ENGINE_ADDRESS    — LiquidationEngine on Unichain
///   COLLATERAL_MANAGER_ADDRESS    — CollateralManager on Unichain
///   UNICHAIN_CHAIN_ID             — Unichain EIP-155 chain ID
///   WETH_ADDRESS                  — WETH on Unichain
///   WBTC_ADDRESS                  — WBTC on Unichain
///
/// Usage:
///   forge script script/deploy/DeployReactiveMonitor.s.sol \
///     --rpc-url $REACTIVE_RPC_URL \
///     --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast
contract DeployReactiveMonitor is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address hookAddress = vm.envAddress("ONLOAN_HOOK_ADDRESS");
        address oracleAddress = vm.envAddress("PRICE_ORACLE_ADDRESS");
        address loanManagerAddress = vm.envAddress("LOAN_MANAGER_ADDRESS");
        address liquidationEngineAddress = vm.envAddress("LIQUIDATION_ENGINE_ADDRESS");
        address collateralManagerAddress = vm.envAddress("COLLATERAL_MANAGER_ADDRESS");
        uint256 unichainChainId = vm.envUint("UNICHAIN_CHAIN_ID");
        address weth = vm.envAddress("WETH_ADDRESS");
        address wbtc = vm.envAddress("WBTC_ADDRESS");

        vm.startBroadcast(deployerKey);

        // ─── 1. Deploy LiquidationRSC ────────────────────────────────
        LiquidationRSC liquidationRSC = new LiquidationRSC(
            unichainChainId,
            hookAddress,
            oracleAddress,
            loanManagerAddress,
            liquidationEngineAddress,
            collateralManagerAddress,
            5 minutes,      // liquidation cooldown
            30 seconds,     // grace period
            1.3e18          // warning threshold (130% HF)
        );

        // Configure known collateral tokens
        // WETH: 18 decimals, 8000 BPS (80%) liquidation threshold
        liquidationRSC.setCollateralConfig(weth, 8000, 18);
        // WBTC: 8 decimals, 8000 BPS (80%) liquidation threshold
        liquidationRSC.setCollateralConfig(wbtc, 8000, 8);

        console.log("LiquidationRSC deployed at:", address(liquidationRSC));

        // ─── 2. Deploy CrossChainCollateralWatcher ────────────────────
        CrossChainCollateralWatcher watcher = new CrossChainCollateralWatcher(
            unichainChainId,
            collateralManagerAddress,
            1000 // max block age
        );

        // Add Ethereum mainnet WETH monitoring (chain ID 1)
        // Note: Replace with actual mainnet token addresses
        // watcher.addMonitoredChain(1, MAINNET_WETH);

        console.log("CrossChainCollateralWatcher deployed at:", address(watcher));

        // ─── 3. Fund RSCs for callback gas ────────────────────────────
        // RSCs need ETH to pay for cross-chain callbacks
        uint256 fundAmount = 0.1 ether;
        if (address(vm.addr(deployerKey)).balance >= fundAmount * 2) {
            payable(address(liquidationRSC)).transfer(fundAmount);
            payable(address(watcher)).transfer(fundAmount);
            console.log("Funded RSCs with", fundAmount, "wei each");
        }

        vm.stopBroadcast();

        // ─── Export addresses ─────────────────────────────────────────
        string memory json = string.concat(
            '{"liquidationRSC":"', vm.toString(address(liquidationRSC)),
            '","crossChainWatcher":"', vm.toString(address(watcher)),
            '"}'
        );
        vm.writeFile("deployments/reactive-addresses.json", json);
        console.log("Addresses exported to deployments/reactive-addresses.json");
    }
}
