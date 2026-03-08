// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {TWAPOracle} from "../../../contracts/src/oracle/TWAPOracle.sol";

contract TWAPOracleTest is Test {
    TWAPOracle public oracle;

    address public weth = makeAddr("WETH");
    address public wbtc = makeAddr("WBTC");
    address public feeder = makeAddr("feeder");

    uint256 constant STALE_THRESHOLD = 1 hours;
    uint256 constant TWAP_WINDOW = 30 minutes;

    function setUp() public {
        oracle = new TWAPOracle(STALE_THRESHOLD, TWAP_WINDOW);
        oracle.setAuthorizedFeeder(feeder, true);

        oracle.configureToken(weth, 18, 1 hours, 5000, 10); // 50% max deviation, 10 obs
        oracle.configureToken(wbtc, 8, 1 hours, 5000, 10);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Configuration
    // ══════════════════════════════════════════════════════════════════

    function test_configureToken() public view {
        (uint8 decimals, uint256 heartbeat, uint256 maxDeviation, uint16 bufferSize, bool configured) =
            oracle.tokenConfigs(weth);
        assertEq(decimals, 18);
        assertEq(heartbeat, 1 hours);
        assertEq(maxDeviation, 5000);
        assertEq(bufferSize, 10);
        assertTrue(configured);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Basic price set/get
    // ══════════════════════════════════════════════════════════════════

    function test_setAndGetPrice() public {
        vm.prank(feeder);
        oracle.setPrice(weth, 3000e18);

        uint256 price = oracle.getPrice(weth);
        assertEq(price, 3000e18);
    }

    function test_getDecimals() public view {
        assertEq(oracle.getDecimals(weth), 18);
        assertEq(oracle.getDecimals(wbtc), 8);
    }

    function test_setPrice_onlyAuthorized() public {
        vm.prank(makeAddr("random"));
        vm.expectRevert(TWAPOracle.NotAuthorizedFeeder.selector);
        oracle.setPrice(weth, 3000e18);
    }

    function test_setPrice_ownerCanAlsoSet() public {
        // Owner (this contract) should also be able to set
        oracle.setPrice(weth, 3000e18);
        assertEq(oracle.getPrice(weth), 3000e18);
    }

    function test_setPrice_rejectsZero() public {
        vm.prank(feeder);
        vm.expectRevert(TWAPOracle.ZeroPriceNotAllowed.selector);
        oracle.setPrice(weth, 0);
    }

    function test_setPrice_rejectsUnconfiguredToken() public {
        vm.prank(feeder);
        vm.expectRevert(abi.encodeWithSelector(TWAPOracle.TokenNotConfigured.selector, makeAddr("random")));
        oracle.setPrice(makeAddr("random"), 100e18);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Heartbeat enforcement
    // ══════════════════════════════════════════════════════════════════

    function test_heartbeat_reverts_whenExceeded() public {
        vm.prank(feeder);
        oracle.setPrice(weth, 3000e18);

        // Advance past heartbeat
        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(
            abi.encodeWithSelector(TWAPOracle.HeartbeatExceeded.selector, weth, 2 hours, 1 hours)
        );
        oracle.getPrice(weth);
    }

    function test_isPriceStale() public {
        vm.prank(feeder);
        oracle.setPrice(weth, 3000e18);

        assertFalse(oracle.isPriceStale(weth));

        vm.warp(block.timestamp + 2 hours);
        assertTrue(oracle.isPriceStale(weth));
    }

    function test_isPriceStale_noObservations() public view {
        assertTrue(oracle.isPriceStale(weth));
    }

    // ══════════════════════════════════════════════════════════════════
    //  Deviation check
    // ══════════════════════════════════════════════════════════════════

    function test_deviationCheck_rejectsOutlier() public {
        vm.startPrank(feeder);
        oracle.setPrice(weth, 3000e18);

        // 60% jump should be rejected (max deviation = 50%)
        vm.expectRevert(
            abi.encodeWithSelector(TWAPOracle.DeviationTooHigh.selector, weth, 3000e18, 4800e18, 6000)
        );
        oracle.setPrice(weth, 4800e18);
        vm.stopPrank();
    }

    function test_deviationCheck_acceptsNormalMove() public {
        vm.startPrank(feeder);
        oracle.setPrice(weth, 3000e18);

        // 30% move should be fine (below 50%)
        oracle.setPrice(weth, 3900e18);
        assertEq(oracle.getPrice(weth), 3900e18);
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════
    //  TWAP calculation
    // ══════════════════════════════════════════════════════════════════

    function test_twap_singleObservation_returnsSpot() public {
        vm.prank(feeder);
        oracle.setPrice(weth, 3000e18);

        uint256 twap = oracle.getTWAP(weth);
        assertEq(twap, 3000e18);
    }

    function test_twap_multipleObservations() public {
        vm.startPrank(feeder);

        // t=0: price = 3000
        oracle.setPrice(weth, 3000e18);

        // t=10min: price = 3100
        vm.warp(block.timestamp + 10 minutes);
        oracle.setPrice(weth, 3100e18);

        // t=20min: price = 3200
        vm.warp(block.timestamp + 10 minutes);
        oracle.setPrice(weth, 3200e18);

        vm.stopPrank();

        // TWAP should be between 3000 and 3200
        uint256 twap = oracle.getTWAP(weth);
        assertGe(twap, 3000e18);
        assertLe(twap, 3200e18);
    }

    function test_twap_stablePrice() public {
        vm.startPrank(feeder);

        oracle.setPrice(weth, 3000e18);
        vm.warp(block.timestamp + 10 minutes);
        oracle.setPrice(weth, 3000e18);
        vm.warp(block.timestamp + 10 minutes);
        oracle.setPrice(weth, 3000e18);

        vm.stopPrank();

        uint256 twap = oracle.getTWAP(weth);
        assertEq(twap, 3000e18);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Ring buffer
    // ══════════════════════════════════════════════════════════════════

    function test_ringBuffer_wrapsAround() public {
        // Buffer size = 10, add 12 observations
        vm.startPrank(feeder);

        for (uint256 i; i < 12; ++i) {
            uint256 price = 3000e18 + (i * 10e18);
            oracle.setPrice(weth, price);
            vm.warp(block.timestamp + 1 minutes);
        }

        vm.stopPrank();

        // Count should be capped at buffer size
        assertEq(oracle.getObservationCount(weth), 10);

        // Latest price should be the last one set
        uint256 latest = oracle.getPrice(weth);
        assertEq(latest, 3000e18 + (11 * 10e18));
    }

    // ══════════════════════════════════════════════════════════════════
    //  Observation details
    // ══════════════════════════════════════════════════════════════════

    function test_getLatestObservation() public {
        vm.prank(feeder);
        oracle.setPrice(weth, 3000e18);

        (uint256 price, uint256 timestamp,) = oracle.getLatestObservation(weth);
        assertEq(price, 3000e18);
        assertEq(timestamp, block.timestamp);
    }

    function test_getLatestObservation_noData() public view {
        (uint256 price, uint256 timestamp,) = oracle.getLatestObservation(weth);
        assertEq(price, 0);
        assertEq(timestamp, 0);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Batch prices
    // ══════════════════════════════════════════════════════════════════

    function test_setBatchPrices() public {
        address[] memory tokens = new address[](2);
        tokens[0] = weth;
        tokens[1] = wbtc;

        uint256[] memory prices = new uint256[](2);
        prices[0] = 3000e18;
        prices[1] = 60000e18;

        vm.prank(feeder);
        oracle.setBatchPrices(tokens, prices);

        assertEq(oracle.getPrice(weth), 3000e18);
        assertEq(oracle.getPrice(wbtc), 60000e18);
    }

    function test_setBatchPrices_lengthMismatch() public {
        address[] memory tokens = new address[](2);
        uint256[] memory prices = new uint256[](1);

        vm.prank(feeder);
        vm.expectRevert(TWAPOracle.ArrayLengthMismatch.selector);
        oracle.setBatchPrices(tokens, prices);
    }

    // ══════════════════════════════════════════════════════════════════
    //  Admin
    // ══════════════════════════════════════════════════════════════════

    function test_setTwapWindow() public {
        oracle.setTwapWindow(1 hours);
        assertEq(oracle.twapWindow(), 1 hours);
    }

    function test_setStalePriceThreshold() public {
        oracle.setStalePriceThreshold(2 hours);
        assertEq(oracle.stalePriceThreshold(), 2 hours);
    }

    function test_setAuthorizedFeeder_onlyOwner() public {
        vm.prank(feeder);
        vm.expectRevert();
        oracle.setAuthorizedFeeder(makeAddr("new"), true);
    }

    // ══════════════════════════════════════════════════════════════════
    //  No observations edge case
    // ══════════════════════════════════════════════════════════════════

    function test_getPrice_noObservations_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(TWAPOracle.InsufficientObservations.selector, weth));
        oracle.getPrice(weth);
    }
}
