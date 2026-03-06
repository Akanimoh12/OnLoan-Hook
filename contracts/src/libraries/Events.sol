// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

library Events {
    event LendingPoolCreated(PoolId indexed poolId, uint256 baseRate, uint256 maxLTV);
    event PoolConfigUpdated(PoolId indexed poolId);

    event LenderDeposited(PoolId indexed poolId, address indexed lender, uint256 amount, uint256 shares);
    event LenderWithdrew(PoolId indexed poolId, address indexed lender, uint256 amount, uint256 shares);
    event InterestDistributed(PoolId indexed poolId, uint256 totalInterest, uint256 protocolFee);

    event CollateralDeposited(address indexed borrower, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed borrower, address indexed token, uint256 amount);
    event LoanCreated(
        address indexed borrower,
        PoolId indexed poolId,
        uint256 collateralAmount,
        uint256 borrowedAmount,
        uint256 interestRate,
        uint256 duration
    );
    event LoanRepaid(address indexed borrower, uint256 principalPaid, uint256 interestPaid, uint256 remaining);
    event LoanFullyRepaid(address indexed borrower, PoolId indexed poolId);
    event CollateralReleased(address indexed borrower, address indexed token, uint256 amount);
    event InterestAccrued(address indexed borrower, uint256 newInterest, uint256 totalAccrued);

    event LoanLiquidated(
        address indexed borrower,
        address indexed liquidator,
        uint256 collateralSeized,
        uint256 debtRepaid,
        uint256 liquidationBonus
    );
    event HealthFactorUpdated(address indexed borrower, uint256 oldFactor, uint256 newFactor);

    event PriceUpdated(address indexed token, uint256 oldPrice, uint256 newPrice, uint256 timestamp);

    event CollateralTokenAdded(address indexed token, uint256 maxLTV, uint256 liquidationThreshold);
    event CollateralTokenRemoved(address indexed token);
    event AuthorizedLiquidatorSet(address indexed liquidator, bool authorized);
}
