// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct LendingPoolState {
    uint256 totalDeposited;
    uint256 totalBorrowed;
    uint256 totalShares;
    uint256 lastUpdateTime;
    uint256 accumulatedProtocolFees;
}

struct InterestRateConfig {
    uint256 baseRate;
    uint256 kinkRate;
    uint256 maxRate;
    uint256 kinkUtilization;
}

struct PoolConfig {
    InterestRateConfig interestRateConfig;
    uint256 protocolFeeRate;
    uint256 minLoanDuration;
    uint256 maxLoanDuration;
    uint256 withdrawalCooldown;
    bool isActive;
}
