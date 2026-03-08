// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IRiskEngine
/// @notice Interface for the OnLoan Risk Engine — centralises risk assessment,
///         warning events, and stress-test simulation.
interface IRiskEngine {
    struct RiskAssessment {
        address borrower;
        uint256 healthFactor;
        uint256 collateralValueUSD;
        uint256 debtValueUSD;
        uint256 liquidationThreshold;
        bool isLiquidatable;
        bool isExpired;
        bool isWarning;
    }

    struct StressResult {
        address borrower;
        uint256 currentHealthFactor;
        uint256 stressedHealthFactor;
        bool wouldBeLiquidatable;
    }

    event RiskWarning(address indexed borrower, uint256 healthFactor, uint256 warningLevel);
    event BatchRiskAssessment(uint256 totalLoans, uint256 atRisk, uint256 liquidatable);

    function assessRisk(address borrower) external view returns (RiskAssessment memory);

    function batchAssessRisk(address[] calldata borrowers)
        external
        view
        returns (RiskAssessment[] memory);

    function getAtRiskLoans(uint256 warningThresholdBps)
        external
        view
        returns (address[] memory borrowers, uint256[] memory healthFactors);

    function simulatePriceImpact(address token, uint256 newPrice)
        external
        view
        returns (StressResult[] memory);

    function simulateMarketCrash(uint256 dropPercentageBps)
        external
        view
        returns (StressResult[] memory);
}
