// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../helpers/TestSetup.sol";
import {Loan} from "../../contracts/src/types/LoanTypes.sol";
import {LendingPoolState} from "../../contracts/src/types/PoolTypes.sol";

contract LiquidationFlowIntegrationTest is TestSetup {
    function setUp() public override {
        super.setUp();
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 5 ether);
        _createLoan(borrower1, address(weth), 5 ether, 10_000e18, 90 days);
    }

    function test_priceDrop_liquidation_fullFlow() public {
        uint256 hfBefore = loanManager.getHealthFactor(borrower1);
        assertGe(hfBefore, PRECISION);

        priceOracle.setPrice(address(weth), 1500e18);

        uint256 hfAfter = loanManager.getHealthFactor(borrower1);
        assertLt(hfAfter, PRECISION);

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertFalse(loan.active);

        uint256 lockedAfter = collateralManager.lockedCollateral(borrower1, address(weth));
        assertEq(lockedAfter, 0);
    }

    function test_gradualPriceDrop_becomesLiquidatable() public {
        assertFalse(liquidationEngine.isLiquidatable(borrower1));

        priceOracle.setPrice(address(weth), 2500e18);
        assertFalse(liquidationEngine.isLiquidatable(borrower1));

        priceOracle.setPrice(address(weth), 1500e18);
        assertTrue(liquidationEngine.isLiquidatable(borrower1));
    }

    function test_liquidation_clearsPoolDebt() public {
        LendingPoolState memory stateBefore = lendingPool.getPoolState(poolId);
        assertEq(stateBefore.totalBorrowed, 10_000e18);

        priceOracle.setPrice(address(weth), 1500e18);

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        LendingPoolState memory stateAfter = lendingPool.getPoolState(poolId);
        assertEq(stateAfter.totalBorrowed, 0);
    }

    function test_interestAccrual_thenLiquidation() public {
        vm.warp(block.timestamp + 60 days);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);

        Loan memory loan = loanManager.getLoan(borrower1);
        uint256 debtWithInterest = loan.borrowedAmount + loan.accruedInterest;
        assertGt(debtWithInterest, 10_000e18);

        priceOracle.setPrice(address(weth), 1500e18);
        assertTrue(liquidationEngine.isLiquidatable(borrower1));

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        Loan memory loanAfter = loanManager.getLoan(borrower1);
        assertFalse(loanAfter.active);
    }

    function test_multipleBorrowers_selectiveLiquidation() public {
        _depositCollateral(borrower2, address(weth), 10 ether);
        _createLoan(borrower2, address(weth), 10 ether, 5000e18, 90 days);

        priceOracle.setPrice(address(weth), 1500e18);

        assertTrue(liquidationEngine.isLiquidatable(borrower1));
        assertFalse(liquidationEngine.isLiquidatable(borrower2));

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        Loan memory loan1 = loanManager.getLoan(borrower1);
        assertFalse(loan1.active);

        Loan memory loan2 = loanManager.getLoan(borrower2);
        assertTrue(loan2.active);
    }

    function test_expiredLoan_liquidation() public {
        vm.warp(block.timestamp + 91 days);
        priceOracle.setPrice(address(weth), 3000e18);

        assertTrue(loanManager.isLoanExpired(borrower1));

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertFalse(loan.active);
    }
}
