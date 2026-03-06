// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../helpers/TestSetup.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {InterestRateConfig} from "../../../contracts/src/types/PoolTypes.sol";
import {InvalidRateParams, NotAuthorized} from "../../../contracts/src/types/Errors.sol";

contract InterestRateModelTest is TestSetup {
    PoolId testPoolId;
    InterestRateConfig defaultConfig;

    function setUp() public override {
        super.setUp();
        testPoolId = PoolId.wrap(bytes32(uint256(99)));
        defaultConfig = InterestRateConfig({
            baseRate: 200,
            kinkRate: 1000,
            maxRate: 2000,
            kinkUtilization: 8000
        });
        interestRateModel.setRateConfig(testPoolId, defaultConfig);
    }

    function test_getInterestRate_atZeroUtilization() public view {
        uint256 rate = interestRateModel.getInterestRate(testPoolId, 0);
        assertEq(rate, 200);
    }

    function test_getInterestRate_atKinkUtilization() public view {
        uint256 rate = interestRateModel.getInterestRate(testPoolId, 8000);
        assertEq(rate, 1000);
    }

    function test_getInterestRate_atFullUtilization() public view {
        uint256 rate = interestRateModel.getInterestRate(testPoolId, 10000);
        assertEq(rate, 2000);
    }

    function test_getInterestRate_belowKink_linearIncrease() public view {
        uint256 rate4000 = interestRateModel.getInterestRate(testPoolId, 4000);
        uint256 rate2000 = interestRateModel.getInterestRate(testPoolId, 2000);
        uint256 rate6000 = interestRateModel.getInterestRate(testPoolId, 6000);

        assertGt(rate4000, rate2000);
        assertGt(rate6000, rate4000);

        uint256 expectedAt4000 = 200 + (4000 * (1000 - 200)) / 8000;
        assertEq(rate4000, expectedAt4000);
    }

    function test_getInterestRate_aboveKink_steepIncrease() public view {
        uint256 rate8500 = interestRateModel.getInterestRate(testPoolId, 8500);
        uint256 rate9000 = interestRateModel.getInterestRate(testPoolId, 9000);
        uint256 rate9500 = interestRateModel.getInterestRate(testPoolId, 9500);

        assertGt(rate9000, rate8500);
        assertGt(rate9500, rate9000);

        uint256 expectedAt9000 = 1000 + ((9000 - 8000) * (2000 - 1000)) / (10000 - 8000);
        assertEq(rate9000, expectedAt9000);
    }

    function test_getUtilizationRate_noDeposits_returnsZero() public view {
        uint256 util = interestRateModel.getUtilizationRate(0, 0);
        assertEq(util, 0);
    }

    function test_getUtilizationRate_noBorrows_returnsZero() public view {
        uint256 util = interestRateModel.getUtilizationRate(1000e18, 0);
        assertEq(util, 0);
    }

    function test_getUtilizationRate_partialBorrow() public view {
        uint256 util = interestRateModel.getUtilizationRate(10000e18, 5000e18);
        assertEq(util, 5000);
    }

    function test_getUtilizationRate_fullBorrow() public view {
        uint256 util = interestRateModel.getUtilizationRate(10000e18, 10000e18);
        assertEq(util, 10000);
    }

    function test_getUtilizationRate_overBorrowed_capsBPS() public view {
        uint256 util = interestRateModel.getUtilizationRate(10000e18, 15000e18);
        assertEq(util, 10000);
    }

    function test_getBorrowRate() public view {
        uint256 rate = interestRateModel.getBorrowRate(testPoolId, 10000e18, 5000e18);
        uint256 util = interestRateModel.getUtilizationRate(10000e18, 5000e18);
        uint256 expected = interestRateModel.getInterestRate(testPoolId, util);
        assertEq(rate, expected);
    }

    function test_getSupplyRate_withProtocolFee() public view {
        uint256 supplyRate = interestRateModel.getSupplyRate(testPoolId, 10000e18, 5000e18, 1000);
        assertGt(supplyRate, 0);

        uint256 borrowRate = interestRateModel.getBorrowRate(testPoolId, 10000e18, 5000e18);
        assertLt(supplyRate, borrowRate);
    }

    function test_getSupplyRate_zeroFee() public view {
        uint256 supplyRateNoFee = interestRateModel.getSupplyRate(testPoolId, 10000e18, 5000e18, 0);
        uint256 supplyRateWithFee = interestRateModel.getSupplyRate(testPoolId, 10000e18, 5000e18, 1000);
        assertGt(supplyRateNoFee, supplyRateWithFee);
    }

    function test_setRateConfig_onlyOwnerOrAuthorized() public {
        address rando = makeAddr("rando");

        vm.prank(rando);
        vm.expectRevert(NotAuthorized.selector);
        interestRateModel.setRateConfig(testPoolId, defaultConfig);
    }

    function test_setRateConfig_authorizedCanSet() public {
        address authorized = makeAddr("authorized");
        interestRateModel.setAuthorized(authorized, true);

        InterestRateConfig memory newConfig = InterestRateConfig({
            baseRate: 300,
            kinkRate: 1200,
            maxRate: 2500,
            kinkUtilization: 7500
        });

        vm.prank(authorized);
        interestRateModel.setRateConfig(testPoolId, newConfig);

        InterestRateConfig memory stored = interestRateModel.getRateConfig(testPoolId);
        assertEq(stored.baseRate, 300);
        assertEq(stored.kinkRate, 1200);
        assertEq(stored.maxRate, 2500);
        assertEq(stored.kinkUtilization, 7500);
    }

    function test_setRateConfig_invalidParams_zeroBaseRate() public {
        InterestRateConfig memory bad = InterestRateConfig({
            baseRate: 0,
            kinkRate: 1000,
            maxRate: 2000,
            kinkUtilization: 8000
        });

        vm.expectRevert(InvalidRateParams.selector);
        interestRateModel.setRateConfig(testPoolId, bad);
    }

    function test_setRateConfig_invalidParams_baseGteKink() public {
        InterestRateConfig memory bad = InterestRateConfig({
            baseRate: 1000,
            kinkRate: 1000,
            maxRate: 2000,
            kinkUtilization: 8000
        });

        vm.expectRevert(InvalidRateParams.selector);
        interestRateModel.setRateConfig(testPoolId, bad);
    }

    function test_setRateConfig_invalidParams_kinkGteMax() public {
        InterestRateConfig memory bad = InterestRateConfig({
            baseRate: 200,
            kinkRate: 2000,
            maxRate: 2000,
            kinkUtilization: 8000
        });

        vm.expectRevert(InvalidRateParams.selector);
        interestRateModel.setRateConfig(testPoolId, bad);
    }

    function test_setRateConfig_invalidParams_kinkUtilTooLow() public {
        InterestRateConfig memory bad = InterestRateConfig({
            baseRate: 200,
            kinkRate: 1000,
            maxRate: 2000,
            kinkUtilization: 999
        });

        vm.expectRevert(InvalidRateParams.selector);
        interestRateModel.setRateConfig(testPoolId, bad);
    }

    function test_setRateConfig_invalidParams_kinkUtilTooHigh() public {
        InterestRateConfig memory bad = InterestRateConfig({
            baseRate: 200,
            kinkRate: 1000,
            maxRate: 2000,
            kinkUtilization: 9501
        });

        vm.expectRevert(InvalidRateParams.selector);
        interestRateModel.setRateConfig(testPoolId, bad);
    }

    function test_setAuthorized_onlyOwner() public {
        address rando = makeAddr("rando");
        address target = makeAddr("target");

        vm.prank(rando);
        vm.expectRevert();
        interestRateModel.setAuthorized(target, true);
    }

    function test_getRateConfig() public view {
        InterestRateConfig memory config = interestRateModel.getRateConfig(testPoolId);
        assertEq(config.baseRate, 200);
        assertEq(config.kinkRate, 1000);
        assertEq(config.maxRate, 2000);
        assertEq(config.kinkUtilization, 8000);
    }
}
