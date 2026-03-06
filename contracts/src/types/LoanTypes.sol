// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct Loan {
    address borrower;
    address collateralToken;
    uint256 collateralAmount;
    uint256 borrowedAmount;
    uint256 accruedInterest;
    uint256 interestRateAtOrigination;
    uint256 startTime;
    uint256 lastAccrualTime;
    uint256 duration;
    bool active;
}

struct CollateralInfo {
    address token;
    bool isSupported;
    uint256 liquidationThreshold;
    uint256 maxLTV;
    uint256 liquidationBonus;
}

struct LenderPosition {
    uint256 deposited;
    uint256 shares;
    uint256 lastDepositTime;
}
