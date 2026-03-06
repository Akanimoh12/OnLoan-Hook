// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

error InsufficientCollateral(uint256 required, uint256 provided);
error LoanNotActive(address borrower);
error LoanAlreadyExists(address borrower);
error BelowMinimumLTV(uint256 ltv);
error AboveMaximumLTV(uint256 ltv, uint256 maxLTV);
error WithdrawalLocked(uint256 unlockTime);
error InsufficientPoolLiquidity(uint256 available, uint256 requested);
error PoolNotActive();
error UnsupportedCollateral(address token);
error UnauthorizedLiquidator(address caller);
error HealthFactorAboveThreshold(uint256 healthFactor);
error LoanExpired(address borrower, uint256 expiry);
error RepaymentExceedsDebt(uint256 repaid, uint256 outstanding);
error ZeroAmount();
error InvalidDuration(uint256 duration);
error CooldownNotElapsed(uint256 remaining);
error NotAuthorized();
error InvalidRateParams();
error InsufficientShares(uint256 available, uint256 requested);
