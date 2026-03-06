// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {PriceOracle} from "../../contracts/src/oracle/PriceOracle.sol";

contract DeployPriceOracle is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 stalePriceThreshold = vm.envOr("STALE_PRICE_THRESHOLD", uint256(1 hours));

        console.log("Deployer:", vm.addr(deployerKey));

        vm.startBroadcast(deployerKey);

        PriceOracle oracle = new PriceOracle(stalePriceThreshold);
        console.log("PriceOracle deployed at:", address(oracle));

        address wethAddr = vm.envOr("WETH_ADDRESS", address(0));
        address wbtcAddr = vm.envOr("WBTC_ADDRESS", address(0));

        if (wethAddr != address(0)) {
            oracle.setTokenDecimals(wethAddr, 18);
            oracle.setPrice(wethAddr, 3000e18);
            console.log("WETH price set:", wethAddr);
        }

        if (wbtcAddr != address(0)) {
            oracle.setTokenDecimals(wbtcAddr, 8);
            oracle.setPrice(wbtcAddr, 60000e18);
            console.log("WBTC price set:", wbtcAddr);
        }

        vm.stopBroadcast();

        string memory json = "oracle";
        string memory out = vm.serializeAddress(json, "priceOracle", address(oracle));
        vm.writeJson(out, "./deployments/oracle.json");
    }
}
