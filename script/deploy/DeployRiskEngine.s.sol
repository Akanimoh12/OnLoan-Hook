// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";

import {RiskEngine} from "../../contracts/src/risk/RiskEngine.sol";

/// @title DeployRiskEngine
/// @notice Deploys the RiskEngine to the same chain as the core protocol (Unichain).
///
/// Required .env:
///   DEPLOYER_PRIVATE_KEY
///   LOAN_MANAGER_ADDRESS
///   COLLATERAL_MANAGER_ADDRESS
///   PRICE_ORACLE_ADDRESS
///
/// Usage:
///   forge script script/deploy/DeployRiskEngine.s.sol \
///     --rpc-url $UNICHAIN_TESTNET_RPC_URL \
///     --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast
contract DeployRiskEngine is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address loanManager = vm.envAddress("LOAN_MANAGER_ADDRESS");
        address collateralManager = vm.envAddress("COLLATERAL_MANAGER_ADDRESS");
        address priceOracle = vm.envAddress("PRICE_ORACLE_ADDRESS");

        vm.startBroadcast(deployerKey);

        RiskEngine riskEngine = new RiskEngine(
            loanManager,
            collateralManager,
            priceOracle,
            1.5e18, // warning threshold (150% HF)
            1.2e18  // critical threshold (120% HF)
        );

        vm.stopBroadcast();

        console.log("=== RiskEngine Deployed ===");
        console.log("RiskEngine:", address(riskEngine));

        string memory json = "risk";
        string memory out = vm.serializeAddress(json, "riskEngine", address(riskEngine));
        vm.writeJson(out, "./deployments/risk-engine.json");
    }
}
