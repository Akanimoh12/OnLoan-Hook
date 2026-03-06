// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../helpers/TestSetup.sol";
import {Loan} from "../../../contracts/src/types/LoanTypes.sol";
import {Events} from "../../../contracts/src/libraries/Events.sol";
import {LoanNotActive, HealthFactorAboveThreshold} from "../../../contracts/src/types/Errors.sol";

contract LiquidationEngineTest is TestSetup {
    function setUp() public override {
        super.setUp();
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);
    }

    function test_liquidateLoan_seizesCollateral() public {
        priceOracle.setPrice(address(weth), 500e18);

        uint256 collBefore = collateralManager.collateralBalances(borrower1, address(weth));

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        uint256 collAfter = collateralManager.collateralBalances(borrower1, address(weth));
        assertLt(collAfter, collBefore);
    }

    function test_liquidateLoan_repaysDebt() public {
        priceOracle.setPrice(address(weth), 500e18);

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        assertFalse(loanManager.isLoanActive(borrower1));
    }

    function test_liquidateLoan_deactivatesLoan() public {
        priceOracle.setPrice(address(weth), 500e18);

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        Loan memory loan = loanManager.getLoan(borrower1);
        assertFalse(loan.active);
    }

    function test_liquidateLoan_emitsEvent() public {
        priceOracle.setPrice(address(weth), 500e18);

        vm.prank(liquidator);
        vm.expectEmit(true, true, false, false);
        emit Events.LoanLiquidated(borrower1, liquidator, 0, 0, 0);
        liquidationEngine.liquidateLoan(borrower1);
    }

    function test_liquidateLoan_healthyPosition_reverts() public {
        vm.prank(liquidator);
        vm.expectRevert();
        liquidationEngine.liquidateLoan(borrower1);
    }

    function test_liquidateLoan_unauthorizedCaller_reverts() public {
        priceOracle.setPrice(address(weth), 500e18);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        liquidationEngine.liquidateLoan(borrower1);
    }

    function test_liquidateLoan_inactiveLoan_reverts() public {
        _repayLoan(borrower1, 5000e18);

        priceOracle.setPrice(address(weth), 500e18);
        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(LoanNotActive.selector, borrower1));
        liquidationEngine.liquidateLoan(borrower1);
    }

    function test_liquidateLoan_expiredLoan_succeeds() public {
        vm.warp(block.timestamp + 31 days);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        assertFalse(loanManager.isLoanActive(borrower1));
    }

    function test_isLiquidatable_belowThreshold_true() public {
        priceOracle.setPrice(address(weth), 500e18);
        assertTrue(liquidationEngine.isLiquidatable(borrower1));
    }

    function test_isLiquidatable_aboveThreshold_false() public view {
        assertFalse(liquidationEngine.isLiquidatable(borrower1));
    }

    function test_isLiquidatable_expired_true() public {
        vm.warp(block.timestamp + 31 days);
        priceOracle.setPrice(address(weth), 3000e18);
        assertTrue(liquidationEngine.isLiquidatable(borrower1));
    }

    function test_isLiquidatable_inactiveLoan_false() public {
        _repayLoan(borrower1, 5000e18);
        assertFalse(liquidationEngine.isLiquidatable(borrower1));
    }

    function test_setAuthorizedLiquidator_onlyOwner() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        liquidationEngine.setAuthorizedLiquidator(rando, true);
    }

    function test_setAuthorizedLiquidator_emitsEvent() public {
        address newLiquidator = makeAddr("newLiquidator");
        vm.expectEmit(true, false, false, true);
        emit Events.AuthorizedLiquidatorSet(newLiquidator, true);
        liquidationEngine.setAuthorizedLiquidator(newLiquidator, true);
    }

    function test_getLiquidationInfo() public {
        (uint256 hf, uint256 debt, uint256 collateral, uint256 bonus) =
            liquidationEngine.getLiquidationInfo(borrower1);

        assertGt(hf, 0);
        assertGt(debt, 0);
        assertGt(collateral, 0);
        assertGt(bonus, 0);
    }

    function test_getLiquidationInfo_afterPriceDrop() public {
        priceOracle.setPrice(address(weth), 500e18);

        (uint256 hf,,,) = liquidationEngine.getLiquidationInfo(borrower1);
        assertLt(hf, 1e18);
    }

    function test_liquidateLoan_reducesActiveBorrowers() public {
        assertEq(loanManager.getActiveBorrowerCount(), 1);

        priceOracle.setPrice(address(weth), 500e18);
        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        assertEq(loanManager.getActiveBorrowerCount(), 0);
    }

    function test_liquidateLoan_poolDebtCleared() public {
        priceOracle.setPrice(address(weth), 500e18);

        vm.prank(liquidator);
        liquidationEngine.liquidateLoan(borrower1);

        assertEq(lendingPool.getPoolState(poolId).totalBorrowed, 0);
    }
}
