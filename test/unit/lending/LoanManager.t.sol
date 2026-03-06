// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../helpers/TestSetup.sol";
import {Loan} from "../../../contracts/src/types/LoanTypes.sol";
import {Events} from "../../../contracts/src/libraries/Events.sol";
import {
    LoanAlreadyExists,
    InvalidDuration,
    AboveMaximumLTV,
    LoanNotActive,
    RepaymentExceedsDebt
} from "../../../contracts/src/types/Errors.sol";

contract LoanManagerTest is TestSetup {
    function setUp() public override {
        super.setUp();
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
    }

    function test_createLoan_storesCorrectState() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertEq(loan.borrower, borrower1);
        assertEq(loan.collateralToken, address(weth));
        assertEq(loan.collateralAmount, 5 ether);
        assertEq(loan.borrowedAmount, 5000e18);
        assertEq(loan.accruedInterest, 0);
        assertTrue(loan.active);
        assertEq(loan.duration, 30 days);
        assertEq(loan.startTime, block.timestamp);
    }

    function test_createLoan_locksCollateral() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        assertEq(collateralManager.lockedCollateral(borrower1, address(weth)), 5 ether);
    }

    function test_createLoan_recordsBorrow() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        assertEq(lendingPool.getPoolState(poolId).totalBorrowed, 5000e18);
    }

    function test_createLoan_duplicateLoan_reverts() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        _depositCollateral(borrower1, address(weth), 5 ether);
        vm.prank(hookAddress);
        vm.expectRevert(abi.encodeWithSelector(LoanAlreadyExists.selector, borrower1));
        loanManager.createLoan(borrower1, poolId, address(weth), 5 ether, 5000e18, 30 days);
    }

    function test_createLoan_insufficientCollateral_reverts() public {
        vm.prank(hookAddress);
        vm.expectRevert();
        loanManager.createLoan(borrower1, poolId, address(weth), 1 ether, 5000e18, 30 days);
    }

    function test_createLoan_invalidDuration_tooShort() public {
        vm.prank(hookAddress);
        vm.expectRevert(abi.encodeWithSelector(InvalidDuration.selector, 1 hours));
        loanManager.createLoan(borrower1, poolId, address(weth), 5 ether, 5000e18, 1 hours);
    }

    function test_createLoan_invalidDuration_tooLong() public {
        vm.prank(hookAddress);
        vm.expectRevert(abi.encodeWithSelector(InvalidDuration.selector, 400 days));
        loanManager.createLoan(borrower1, poolId, address(weth), 5 ether, 5000e18, 400 days);
    }

    function test_createLoan_onlyHook() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        loanManager.createLoan(borrower1, poolId, address(weth), 5 ether, 5000e18, 30 days);
    }

    function test_createLoan_emitsEvent() public {
        vm.prank(hookAddress);
        vm.expectEmit(true, true, false, false);
        emit Events.LoanCreated(borrower1, poolId, 5 ether, 5000e18, 0, 30 days);
        loanManager.createLoan(borrower1, poolId, address(weth), 5 ether, 5000e18, 30 days);
    }

    function test_createLoan_aboveMaxLTV_reverts() public {
        vm.prank(hookAddress);
        vm.expectRevert();
        loanManager.createLoan(borrower1, poolId, address(weth), 5 ether, 20000e18, 30 days);
    }

    function test_accrueInterest_calculatesCorrectly() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        vm.warp(block.timestamp + 30 days);
        priceOracle.setPrice(address(weth), 3000e18);
        loanManager.accrueInterest(borrower1);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertGt(loan.accruedInterest, 0);
    }

    function test_accrueInterest_timeWeighted() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 365 days);

        vm.warp(block.timestamp + 30 days);
        priceOracle.setPrice(address(weth), 3000e18);
        loanManager.accrueInterest(borrower1);
        Loan memory loan30 = loanManager.getLoan(borrower1);
        uint256 interest30 = loan30.accruedInterest;

        _repayLoan(borrower1, loan30.borrowedAmount + loan30.accruedInterest);

        _depositCollateral(borrower2, address(weth), 10 ether);
        _createLoan(borrower2, address(weth), 5 ether, 5000e18, 365 days);
        vm.warp(block.timestamp + 60 days);
        priceOracle.setPrice(address(weth), 3000e18);
        loanManager.accrueInterest(borrower2);
        Loan memory loan60 = loanManager.getLoan(borrower2);

        assertGt(loan60.accruedInterest, interest30);
    }

    function test_accrueInterest_inactiveLoan_noEffect() public {
        loanManager.accrueInterest(borrower1);
        Loan memory loan = loanManager.getLoan(borrower1);
        assertEq(loan.accruedInterest, 0);
    }

    function test_repay_interestFirst_thenPrincipal() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 365 days);

        vm.warp(block.timestamp + 30 days);
        priceOracle.setPrice(address(weth), 3000e18);
        loanManager.accrueInterest(borrower1);
        Loan memory loanBefore = loanManager.getLoan(borrower1);
        uint256 interestOwed = loanBefore.accruedInterest;

        _repayLoan(borrower1, interestOwed);

        Loan memory loanAfter = loanManager.getLoan(borrower1);
        assertEq(loanAfter.accruedInterest, 0);
        assertEq(loanAfter.borrowedAmount, 5000e18);
        assertTrue(loanAfter.active);
    }

    function test_repay_partial_updatesDebt() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 365 days);

        _repayLoan(borrower1, 2000e18);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertEq(loan.borrowedAmount, 3000e18);
        assertTrue(loan.active);
    }

    function test_repay_full_deactivatesLoan() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        vm.warp(block.timestamp + 10 days);
        priceOracle.setPrice(address(weth), 3000e18);
        loanManager.accrueInterest(borrower1);
        Loan memory loan = loanManager.getLoan(borrower1);
        uint256 totalDebt = loan.borrowedAmount + loan.accruedInterest;

        _repayLoan(borrower1, totalDebt);

        Loan memory loanAfter = loanManager.getLoan(borrower1);
        assertFalse(loanAfter.active);
    }

    function test_repay_full_unlocksCollateral() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        _repayLoan(borrower1, 5000e18);

        assertEq(collateralManager.lockedCollateral(borrower1, address(weth)), 0);
    }

    function test_repay_full_emitsLoanFullyRepaid() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        vm.prank(hookAddress);
        vm.expectEmit(true, true, false, true);
        emit Events.LoanFullyRepaid(borrower1, poolId);
        loanManager.repay(borrower1, 5000e18);
    }

    function test_repay_exceedsDebt_reverts() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        vm.prank(hookAddress);
        vm.expectRevert(abi.encodeWithSelector(RepaymentExceedsDebt.selector, 10000e18, 5000e18));
        loanManager.repay(borrower1, 10000e18);
    }

    function test_repay_inactiveLoan_reverts() public {
        vm.prank(hookAddress);
        vm.expectRevert(abi.encodeWithSelector(LoanNotActive.selector, borrower1));
        loanManager.repay(borrower1, 1000e18);
    }

    function test_repay_onlyHook() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        loanManager.repay(borrower1, 1000e18);
    }

    function test_getHealthFactor_healthy() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        uint256 hf = loanManager.getHealthFactor(borrower1);
        assertGt(hf, 1e18);
    }

    function test_getHealthFactor_atThreshold() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        uint256 priceForThreshold = (5000e18 * 1e18 * 10000) / (5 ether * 8000);
        priceOracle.setPrice(address(weth), priceForThreshold);

        uint256 hf = loanManager.getHealthFactor(borrower1);
        assertApproxEqAbs(hf, 1e18, 1e15);
    }

    function test_getHealthFactor_belowThreshold() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        priceOracle.setPrice(address(weth), 500e18);

        uint256 hf = loanManager.getHealthFactor(borrower1);
        assertLt(hf, 1e18);
    }

    function test_getHealthFactor_noActiveLoan() public view {
        uint256 hf = loanManager.getHealthFactor(borrower1);
        assertEq(hf, type(uint256).max);
    }

    function test_isLoanActive() public {
        assertFalse(loanManager.isLoanActive(borrower1));
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        assertTrue(loanManager.isLoanActive(borrower1));
    }

    function test_isLoanExpired_beforeDuration() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        assertFalse(loanManager.isLoanExpired(borrower1));
    }

    function test_isLoanExpired_afterDuration() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        vm.warp(block.timestamp + 31 days);
        assertTrue(loanManager.isLoanExpired(borrower1));
    }

    function test_isLoanExpired_inactiveLoan() public view {
        assertFalse(loanManager.isLoanExpired(borrower1));
    }

    function test_getActiveBorrowerCount() public {
        assertEq(loanManager.getActiveBorrowerCount(), 0);

        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        assertEq(loanManager.getActiveBorrowerCount(), 1);
    }

    function test_getActiveBorrowers() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        address[] memory borrowers = loanManager.getActiveBorrowers();
        assertEq(borrowers.length, 1);
        assertEq(borrowers[0], borrower1);
    }

    function test_getOutstandingDebt() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        uint256 debt = loanManager.getOutstandingDebt(borrower1);
        assertEq(debt, 5000e18);

        vm.warp(block.timestamp + 30 days);
        uint256 debtWithInterest = loanManager.getOutstandingDebt(borrower1);
        assertGt(debtWithInterest, 5000e18);
    }

    function test_getBorrowerPool() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
        assertEq(PoolId.unwrap(loanManager.getBorrowerPool(borrower1)), PoolId.unwrap(poolId));
    }

    function test_markLoanLiquidated_onlyLiquidationEngine() public {
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        loanManager.markLoanLiquidated(borrower1);
    }

    function test_setHook_onlyOwner() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        loanManager.setHook(rando);
    }

    function test_setLiquidationEngine_onlyOwner() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        loanManager.setLiquidationEngine(rando);
    }
}
