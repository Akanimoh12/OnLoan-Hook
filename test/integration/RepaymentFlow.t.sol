// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../helpers/TestSetup.sol";
import {Loan} from "../../contracts/src/types/LoanTypes.sol";
import {LendingPoolState} from "../../contracts/src/types/PoolTypes.sol";

contract RepaymentFlowIntegrationTest is TestSetup {
    function setUp() public override {
        super.setUp();
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 10_000e18, 180 days);
    }

    function test_partialRepayments_reducesDebt() public {
        vm.warp(block.timestamp + 30 days);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);

        Loan memory loanBefore = loanManager.getLoan(borrower1);
        uint256 debtBefore = loanBefore.borrowedAmount + loanBefore.accruedInterest;
        assertGt(debtBefore, 10_000e18);

        _repayLoan(borrower1, 3000e18);

        Loan memory loanAfter = loanManager.getLoan(borrower1);
        uint256 debtAfter = loanAfter.borrowedAmount + loanAfter.accruedInterest;
        assertLt(debtAfter, debtBefore);

        assertTrue(loanAfter.active);
    }

    function test_multiplePartialRepayments_thenFullRepay() public {
        vm.warp(block.timestamp + 10 days);
        priceOracle.setPrice(address(weth), 3000e18);

        _repayLoan(borrower1, 2000e18);
        Loan memory loan1 = loanManager.getLoan(borrower1);
        uint256 debt1 = loan1.borrowedAmount + loan1.accruedInterest;

        vm.warp(block.timestamp + 10 days);
        priceOracle.setPrice(address(weth), 3000e18);

        _repayLoan(borrower1, 3000e18);
        Loan memory loan2 = loanManager.getLoan(borrower1);
        uint256 debt2 = loan2.borrowedAmount + loan2.accruedInterest;
        assertLt(debt2, debt1);

        vm.warp(block.timestamp + 10 days);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);
        Loan memory loanFinal = loanManager.getLoan(borrower1);
        uint256 finalDebt = loanFinal.borrowedAmount + loanFinal.accruedInterest;

        _repayLoan(borrower1, finalDebt);

        Loan memory loanClosed = loanManager.getLoan(borrower1);
        assertFalse(loanClosed.active);
    }

    function test_fullRepay_unlocksCollateral() public {
        uint256 lockedBefore = collateralManager.lockedCollateral(borrower1, address(weth));
        assertEq(lockedBefore, 10 ether);

        _repayLoan(borrower1, 10_000e18);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertFalse(loan.active);

        uint256 lockedAfter = collateralManager.lockedCollateral(borrower1, address(weth));
        assertEq(lockedAfter, 0);
    }

    function test_repayAfterPriceIncrease_staysHealthy() public {
        priceOracle.setPrice(address(weth), 5000e18);

        uint256 hf = loanManager.getHealthFactor(borrower1);
        assertGt(hf, PRECISION);

        _repayLoan(borrower1, 5000e18);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertEq(loan.borrowedAmount, 5000e18);

        uint256 hfAfter = loanManager.getHealthFactor(borrower1);
        assertGt(hfAfter, hf);
    }

    function test_repayJustBeforeExpiry() public {
        vm.warp(block.timestamp + 179 days);
        priceOracle.setPrice(address(weth), 3000e18);

        assertFalse(loanManager.isLoanExpired(borrower1));

        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);

        Loan memory loan = loanManager.getLoan(borrower1);
        uint256 debt = loan.borrowedAmount + loan.accruedInterest;
        _repayLoan(borrower1, debt);

        Loan memory loanClosed = loanManager.getLoan(borrower1);
        assertFalse(loanClosed.active);
    }

    function test_poolAccountingAfterRepayments() public {
        LendingPoolState memory stateBefore = lendingPool.getPoolState(poolId);
        assertEq(stateBefore.totalDeposited, 50_000e18);
        assertEq(stateBefore.totalBorrowed, 10_000e18);

        _repayLoan(borrower1, 10_000e18);

        LendingPoolState memory stateAfter = lendingPool.getPoolState(poolId);
        assertGe(stateAfter.totalDeposited, stateBefore.totalDeposited);
        assertEq(stateAfter.totalBorrowed, 0);
    }
}
