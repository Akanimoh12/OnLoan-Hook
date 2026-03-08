// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {MockERC20} from "../../test/helpers/MockERC20.sol";

/// @title DeployTestnetTokens
/// @notice Deploys mock ERC-20 tokens for testnet usage.
///         Skip this if the testnet already has WETH/WBTC/USDC deployed.
///
/// Usage:
///   forge script script/deploy/DeployTestnetTokens.s.sol \
///     --rpc-url $UNICHAIN_TESTNET_RPC_URL \
///     --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast
contract DeployTestnetTokens is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH", 18);
        MockERC20 wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);

        // Mint test tokens to deployer
        weth.mint(deployer, 1000 ether);
        wbtc.mint(deployer, 100e8);
        usdc.mint(deployer, 1_000_000e6);

        vm.stopBroadcast();

        console.log("=== Testnet Tokens Deployed ===");
        console.log("WETH:", address(weth));
        console.log("WBTC:", address(wbtc));
        console.log("USDC:", address(usdc));
        console.log("");
        console.log("Add to .env:");
        console.log(string.concat("WETH_ADDRESS=", vm.toString(address(weth))));
        console.log(string.concat("WBTC_ADDRESS=", vm.toString(address(wbtc))));

        // Export addresses
        string memory json = "tokens";
        vm.serializeAddress(json, "weth", address(weth));
        vm.serializeAddress(json, "wbtc", address(wbtc));
        string memory out = vm.serializeAddress(json, "usdc", address(usdc));
        vm.writeJson(out, "./deployments/testnet-tokens.json");
    }
}
