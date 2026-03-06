// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

/// @title TestSetup
/// @notice Base test setup — deploys core contracts for all test suites
/// @dev Contracts to deploy in setUp():
///   - OnLoanHook
///   - LendingPool
///   - InterestRateModel
///   - CollateralManager
///   - LoanManager
///   - LiquidationEngine
///   - PriceOracle
///   - LendingReceipt6909
///   - MockERC20 tokens (collateral + borrow assets)
abstract contract TestSetup is Test {
    function setUp() public virtual {
        // TODO: Deploy all core contracts
    }
}
