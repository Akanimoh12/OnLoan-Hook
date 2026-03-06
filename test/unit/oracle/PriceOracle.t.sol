// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../helpers/TestSetup.sol";
import {Events} from "../../../contracts/src/libraries/Events.sol";

contract PriceOracleTest is TestSetup {
    function test_setPrice_updatesPrice() public {
        priceOracle.setPrice(address(weth), 3500e18);
        assertEq(priceOracle.getPrice(address(weth)), 3500e18);
    }

    function test_setPrice_emitsPriceUpdated() public {
        vm.expectEmit(true, false, false, true);
        emit Events.PriceUpdated(address(weth), 3000e18, 3500e18, block.timestamp);
        priceOracle.setPrice(address(weth), 3500e18);
    }

    function test_setPrice_zeroPriceReverts() public {
        vm.expectRevert(PriceOracle.ZeroPriceNotAllowed.selector);
        priceOracle.setPrice(address(weth), 0);
    }

    function test_getPrice_stalePrice_reverts() public {
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.StalePrice.selector, address(weth)));
        priceOracle.getPrice(address(weth));
    }

    function test_getPrice_withinThreshold_succeeds() public view {
        uint256 price = priceOracle.getPrice(address(weth));
        assertEq(price, 3000e18);
    }

    function test_getPrice_afterRefresh_succeeds() public {
        vm.warp(block.timestamp + 50 minutes);
        priceOracle.setPrice(address(weth), 3100e18);
        assertEq(priceOracle.getPrice(address(weth)), 3100e18);
    }

    function test_setBatchPrices_updatesAll() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(wbtc);

        uint256[] memory newPrices = new uint256[](2);
        newPrices[0] = 3200e18;
        newPrices[1] = 62000e18;

        priceOracle.setBatchPrices(tokens, newPrices);
        assertEq(priceOracle.getPrice(address(weth)), 3200e18);
        assertEq(priceOracle.getPrice(address(wbtc)), 62000e18);
    }

    function test_setBatchPrices_lengthMismatch_reverts() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(wbtc);

        uint256[] memory newPrices = new uint256[](1);
        newPrices[0] = 3200e18;

        vm.expectRevert(PriceOracle.ArrayLengthMismatch.selector);
        priceOracle.setBatchPrices(tokens, newPrices);
    }

    function test_setBatchPrices_zeroPriceReverts() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        uint256[] memory newPrices = new uint256[](1);
        newPrices[0] = 0;

        vm.expectRevert(PriceOracle.ZeroPriceNotAllowed.selector);
        priceOracle.setBatchPrices(tokens, newPrices);
    }

    function test_getPrice_onlyOwner_canSet() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        priceOracle.setPrice(address(weth), 4000e18);
    }

    function test_setTokenDecimals() public {
        priceOracle.setTokenDecimals(address(weth), 18);
        assertEq(priceOracle.getDecimals(address(weth)), 18);
    }

    function test_isPriceStale_fresh() public view {
        assertFalse(priceOracle.isPriceStale(address(weth)));
    }

    function test_isPriceStale_afterThreshold() public {
        vm.warp(block.timestamp + 2 hours);
        assertTrue(priceOracle.isPriceStale(address(weth)));
    }

    function test_setStalePriceThreshold() public {
        priceOracle.setStalePriceThreshold(2 hours);
        assertEq(priceOracle.stalePriceThreshold(), 2 hours);
        vm.warp(block.timestamp + 90 minutes);
        assertFalse(priceOracle.isPriceStale(address(weth)));
    }

    function test_getDecimals_returnsCorrect() public view {
        assertEq(priceOracle.getDecimals(address(weth)), 18);
        assertEq(priceOracle.getDecimals(address(wbtc)), 8);
        assertEq(priceOracle.getDecimals(address(usdc)), 6);
    }
}
