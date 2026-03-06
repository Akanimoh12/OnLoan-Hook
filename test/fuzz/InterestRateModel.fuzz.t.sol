// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../helpers/TestSetup.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {InterestRateConfig} from "../../contracts/src/types/PoolTypes.sol";

contract InterestRateModelFuzzTest is TestSetup {
    PoolId fuzzPoolId;

    function setUp() public override {
        super.setUp();
        fuzzPoolId = PoolId.wrap(bytes32(uint256(99)));
        interestRateModel.setRateConfig(
            fuzzPoolId,
            InterestRateConfig({baseRate: 200, kinkRate: 1000, maxRate: 2000, kinkUtilization: 8000})
        );
    }

    function testFuzz_interestRate_alwaysWithinBounds(uint256 utilization) public view {
        utilization = bound(utilization, 0, 10000);
        uint256 rate = interestRateModel.getInterestRate(fuzzPoolId, utilization);
        assertGe(rate, 200);
        assertLe(rate, 2000);
    }

    function testFuzz_interestRate_monotonicallyIncreasing(uint256 u1, uint256 u2) public view {
        u1 = bound(u1, 0, 10000);
        u2 = bound(u2, 0, 10000);
        uint256 rate1 = interestRateModel.getInterestRate(fuzzPoolId, u1);
        uint256 rate2 = interestRateModel.getInterestRate(fuzzPoolId, u2);
        if (u1 < u2) {
            assertLe(rate1, rate2);
        } else if (u1 > u2) {
            assertGe(rate1, rate2);
        } else {
            assertEq(rate1, rate2);
        }
    }

    function testFuzz_supplyRate_neverExceedsBorrowRate(uint256 utilization, uint256 feeBps) public view {
        utilization = bound(utilization, 1, 10000);
        feeBps = bound(feeBps, 0, 5000);
        uint256 totalDeposited = 100_000e18;
        uint256 totalBorrowed = (totalDeposited * utilization) / 10000;

        uint256 borrowRate = interestRateModel.getBorrowRate(fuzzPoolId, totalDeposited, totalBorrowed);
        uint256 supplyRate = interestRateModel.getSupplyRate(fuzzPoolId, totalDeposited, totalBorrowed, feeBps);

        assertLe(supplyRate, borrowRate);
    }

    function testFuzz_utilizationRate_bounded(uint256 deposited, uint256 borrowed) public view {
        deposited = bound(deposited, 1, type(uint128).max);
        borrowed = bound(borrowed, 0, deposited * 2);
        uint256 util = interestRateModel.getUtilizationRate(deposited, borrowed);
        assertLe(util, 10000);
    }

    function testFuzz_utilizationRate_proportional(uint256 deposited, uint256 borrowed) public view {
        deposited = bound(deposited, 1e18, type(uint128).max);
        borrowed = bound(borrowed, 0, deposited);
        uint256 util = interestRateModel.getUtilizationRate(deposited, borrowed);
        uint256 expected = (borrowed * 10000) / deposited;
        assertEq(util, expected);
    }
}
