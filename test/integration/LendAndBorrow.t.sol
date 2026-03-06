// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../helpers/TestSetup.sol";
import {Loan} from "../../contracts/src/types/LoanTypes.sol";
import {LendingPoolState} from "../../contracts/src/types/PoolTypes.sol";

contract LendAndBorrowIntegrationTest is TestSetup {
    function setUp() public override {
        super.setUp();
    }

    function test_fullHappyPath_depositBorrowRepayWithdraw() public {
        uint256 shares1 = _depositToPool(lender1, 50_000e18);

        _depositCollateral(borrower1, address(weth), 5 ether);

        uint256 collateralVal = collateralManager.getCollateralValueUSD(borrower1, address(weth));
        assertEq(collateralVal, 15_000e18);

        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertEq(loan.borrowedAmount, 5000e18);

        vm.warp(block.timestamp + 15 days);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);

        Loan memory loanAfter = loanManager.getLoan(borrower1);
        uint256 currentDebt = loanAfter.borrowedAmount + loanAfter.accruedInterest;
        assertGt(currentDebt, 5000e18);

        _repayLoan(borrower1, currentDebt);

        Loan memory loanRepaid = loanManager.getLoan(borrower1);
        assertFalse(loanRepaid.active);

        vm.warp(block.timestamp + 1 days + 1);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        uint256 withdrawn = lendingPool.withdraw(poolId, lender1, shares1);
        assertGt(withdrawn, 50_000e18);
    }

    function test_multipleLenders_singleBorrower() public {
        uint256 shares1 = _depositToPool(lender1, 30_000e18);
        uint256 shares2 = _depositToPool(lender2, 20_000e18);

        LendingPoolState memory poolState = lendingPool.getPoolState(poolId);
        assertEq(poolState.totalDeposited, 50_000e18);

        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 10_000e18, 60 days);

        vm.warp(block.timestamp + 60 days);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);

        Loan memory loan = loanManager.getLoan(borrower1);
        uint256 debt = loan.borrowedAmount + loan.accruedInterest;
        _repayLoan(borrower1, debt);

        vm.warp(block.timestamp + 1 days + 1);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        uint256 w1 = lendingPool.withdraw(poolId, lender1, shares1);

        vm.prank(hookAddress);
        uint256 w2 = lendingPool.withdraw(poolId, lender2, shares2);

        assertGt(w1, 30_000e18);
        assertGt(w2, 20_000e18);
        assertGt(w1, w2);
    }

    function test_multipleBorrowers_singleLender() public {
        uint256 shares = _depositToPool(lender1, 50_000e18);

        _depositCollateral(borrower1, address(weth), 5 ether);
        _depositCollateral(borrower2, address(weth), 5 ether);

        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        _createLoan(borrower2, address(weth), 5 ether, 3000e18, 30 days);

        vm.warp(block.timestamp + 30 days);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);
        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower2);

        Loan memory loan1 = loanManager.getLoan(borrower1);
        Loan memory loan2 = loanManager.getLoan(borrower2);

        _repayLoan(borrower1, loan1.borrowedAmount + loan1.accruedInterest);
        _repayLoan(borrower2, loan2.borrowedAmount + loan2.accruedInterest);

        vm.warp(block.timestamp + 1 days + 1);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        uint256 withdrawn = lendingPool.withdraw(poolId, lender1, shares);
        assertGt(withdrawn, 50_000e18);
    }

    function test_btcCollateral_fullFlow() public {
        _depositToPool(lender1, 50_000e18);

        _depositCollateral(borrower1, address(wbtc), 1e8);

        uint256 collateralVal = collateralManager.getCollateralValueUSD(borrower1, address(wbtc));
        assertEq(collateralVal, 60_000e18);

        _createLoan(borrower1, address(wbtc), 1e8, 20_000e18, 90 days);

        vm.warp(block.timestamp + 45 days);
        priceOracle.setPrice(address(wbtc), 60000e18);

        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);

        Loan memory loan = loanManager.getLoan(borrower1);
        _repayLoan(borrower1, loan.borrowedAmount + loan.accruedInterest);

        Loan memory loanRepaid = loanManager.getLoan(borrower1);
        assertFalse(loanRepaid.active);
    }

    function test_interestAccruesOverTime() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 10 ether, 10_000e18, 365 days);

        vm.warp(block.timestamp + 30 days);
        priceOracle.setPrice(address(weth), 3000e18);
        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);
        Loan memory loan30 = loanManager.getLoan(borrower1);
        uint256 debt30 = loan30.borrowedAmount + loan30.accruedInterest;

        vm.warp(block.timestamp + 30 days);
        priceOracle.setPrice(address(weth), 3000e18);
        vm.prank(hookAddress);
        loanManager.accrueInterest(borrower1);
        Loan memory loan60 = loanManager.getLoan(borrower1);
        uint256 debt60 = loan60.borrowedAmount + loan60.accruedInterest;

        assertGt(debt30, 10_000e18);
        assertGt(debt60, debt30);

        uint256 interest30 = debt30 - 10_000e18;
        uint256 interest60 = debt60 - debt30;

        assertApproxEqRel(interest30, interest60, 5e16);
    }
}
