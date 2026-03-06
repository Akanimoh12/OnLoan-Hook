// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../helpers/TestSetup.sol";
import {Loan} from "../../contracts/src/types/LoanTypes.sol";
import {LendingPoolState} from "../../contracts/src/types/PoolTypes.sol";

contract GasBenchmarksTest is TestSetup {
    function setUp() public override {
        super.setUp();
    }

    function test_gas_deposit() public {
        vm.prank(hookAddress);
        uint256 gasBefore = gasleft();
        lendingPool.deposit(poolId, lender1, 10_000e18);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: deposit", gasUsed);
    }

    function test_gas_withdraw() public {
        uint256 shares = _depositToPool(lender1, 10_000e18);

        vm.warp(block.timestamp + 1 days + 1);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        uint256 gasBefore = gasleft();
        lendingPool.withdraw(poolId, lender1, shares);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: withdraw", gasUsed);
    }

    function test_gas_depositCollateral() public {
        vm.prank(borrower1);
        uint256 gasBefore = gasleft();
        collateralManager.depositCollateral(borrower1, address(weth), 5 ether);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: depositCollateral", gasUsed);
    }

    function test_gas_createLoan() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);

        vm.prank(hookAddress);
        uint256 gasBefore = gasleft();
        loanManager.createLoan(borrower1, poolId, address(weth), 5 ether, 5000e18, 30 days);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: createLoan", gasUsed);
    }

    function test_gas_accrueInterest() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        vm.warp(block.timestamp + 15 days);
        priceOracle.setPrice(address(weth), 3000e18);

        vm.prank(hookAddress);
        uint256 gasBefore = gasleft();
        loanManager.accrueInterest(borrower1);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: accrueInterest", gasUsed);
    }

    function test_gas_repayPartial() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        vm.prank(hookAddress);
        uint256 gasBefore = gasleft();
        loanManager.repay(borrower1, 2000e18);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: repayPartial", gasUsed);
    }

    function test_gas_repayFull() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        vm.prank(hookAddress);
        uint256 gasBefore = gasleft();
        loanManager.repay(borrower1, 5000e18);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: repayFull", gasUsed);
    }

    function test_gas_liquidate() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 5 ether);
        _createLoan(borrower1, address(weth), 5 ether, 10_000e18, 90 days);

        priceOracle.setPrice(address(weth), 1500e18);

        vm.prank(liquidator);
        uint256 gasBefore = gasleft();
        liquidationEngine.liquidateLoan(borrower1);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: liquidate", gasUsed);
    }

    function test_gas_getHealthFactor() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        uint256 gasBefore = gasleft();
        loanManager.getHealthFactor(borrower1);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: getHealthFactor", gasUsed);
    }

    function test_gas_setPrice() public {
        uint256 gasBefore = gasleft();
        priceOracle.setPrice(address(weth), 3500e18);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: setPrice", gasUsed);
    }

    function test_gas_getCollateralValueUSD() public {
        _depositCollateral(borrower1, address(weth), 5 ether);

        uint256 gasBefore = gasleft();
        collateralManager.getCollateralValueUSD(borrower1, address(weth));
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: getCollateralValueUSD", gasUsed);
    }

    function test_gas_isLiquidatable() public {
        _depositToPool(lender1, 50_000e18);
        _depositCollateral(borrower1, address(weth), 10 ether);
        _createLoan(borrower1, address(weth), 5 ether, 5000e18, 30 days);

        uint256 gasBefore = gasleft();
        liquidationEngine.isLiquidatable(borrower1);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas: isLiquidatable", gasUsed);
    }
}
