// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Loan, CollateralInfo} from "../types/LoanTypes.sol";
import {HealthFactor} from "../libraries/HealthFactor.sol";
import {CollateralValuation} from "../libraries/CollateralValuation.sol";
import {InterestAccrual} from "../libraries/InterestAccrual.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IRiskEngine} from "../interfaces/IRiskEngine.sol";

/// @title RiskEngine
/// @notice Centralised risk assessment, warning emission, and stress-test simulation
///         for the OnLoan protocol.
///
/// Features:
///   - Single-borrower and batch risk assessment
///   - At-risk loan scanning with configurable warning thresholds
///   - Price impact simulation (single token or market-wide crash)
///   - Warning event emission at configurable health factor levels
///   - Risk parameter configuration
contract RiskEngine is IRiskEngine, Ownable {
    // ──────────────────────────────────────────────────────────────────
    //  Dependencies
    // ──────────────────────────────────────────────────────────────────

    ILoanManager public loanManager;
    ICollateralManager public collateralManager;
    IPriceOracle public priceOracle;

    // ──────────────────────────────────────────────────────────────────
    //  Config
    // ──────────────────────────────────────────────────────────────────

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS = 10_000;

    /// @notice Health factor below which a warning event is emitted (e.g., 1.5e18 = 150%).
    uint256 public warningThreshold;

    /// @notice Health factor below which a critical warning is emitted (e.g., 1.2e18 = 120%).
    uint256 public criticalThreshold;

    // ──────────────────────────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────────────────────────

    constructor(
        address _loanManager,
        address _collateralManager,
        address _priceOracle,
        uint256 _warningThreshold,
        uint256 _criticalThreshold
    ) Ownable(msg.sender) {
        loanManager = ILoanManager(_loanManager);
        collateralManager = ICollateralManager(_collateralManager);
        priceOracle = IPriceOracle(_priceOracle);
        warningThreshold = _warningThreshold;
        criticalThreshold = _criticalThreshold;
    }

    // ──────────────────────────────────────────────────────────────────
    //  Admin
    // ──────────────────────────────────────────────────────────────────

    function setWarningThreshold(uint256 _threshold) external onlyOwner {
        warningThreshold = _threshold;
    }

    function setCriticalThreshold(uint256 _threshold) external onlyOwner {
        criticalThreshold = _threshold;
    }

    function setDependencies(
        address _loanManager,
        address _collateralManager,
        address _priceOracle
    ) external onlyOwner {
        loanManager = ILoanManager(_loanManager);
        collateralManager = ICollateralManager(_collateralManager);
        priceOracle = IPriceOracle(_priceOracle);
    }

    // ──────────────────────────────────────────────────────────────────
    //  Risk assessment
    // ──────────────────────────────────────────────────────────────────

    /// @notice Full risk assessment for a single borrower.
    function assessRisk(address borrower) public view returns (RiskAssessment memory result) {
        Loan memory loan = loanManager.getLoan(borrower);
        result.borrower = borrower;

        if (!loan.active) {
            result.healthFactor = type(uint256).max;
            return result;
        }

        uint256 debt = InterestAccrual.getOutstandingDebt(loan);
        uint256 price = priceOracle.getPrice(loan.collateralToken);
        uint8 decimals = priceOracle.getDecimals(loan.collateralToken);

        uint256 collateralValue = CollateralValuation.getCollateralValueUSD(
            loan.collateralAmount,
            price,
            decimals
        );

        CollateralInfo memory info = collateralManager.getCollateralInfo(loan.collateralToken);
        uint256 hf = HealthFactor.calculateHealthFactor(collateralValue, debt, info.liquidationThreshold);

        result.healthFactor = hf;
        result.collateralValueUSD = collateralValue;
        result.debtValueUSD = debt;
        result.liquidationThreshold = info.liquidationThreshold;
        result.isLiquidatable = HealthFactor.isLiquidatable(hf);
        result.isExpired = block.timestamp > loan.startTime + loan.duration;
        result.isWarning = hf < warningThreshold && !result.isLiquidatable;
    }

    /// @notice Batch risk assessment.
    function batchAssessRisk(address[] calldata borrowers)
        external
        view
        returns (RiskAssessment[] memory results)
    {
        results = new RiskAssessment[](borrowers.length);
        for (uint256 i; i < borrowers.length; ++i) {
            results[i] = assessRisk(borrowers[i]);
        }
    }

    /// @notice Scan all active loans and return those below the given warning threshold.
    /// @param warningThresholdBps Expressed as a health factor value (e.g., 15000 = 1.5x).
    ///        Internally converted to 1e18 scale.
    function getAtRiskLoans(uint256 warningThresholdBps)
        external
        view
        returns (address[] memory borrowers, uint256[] memory healthFactors)
    {
        address[] memory allBorrowers = loanManager.getActiveBorrowers();
        uint256 threshold = (warningThresholdBps * PRECISION) / BPS;

        // First pass — count at-risk
        uint256 count;
        for (uint256 i; i < allBorrowers.length; ++i) {
            uint256 hf = loanManager.getHealthFactor(allBorrowers[i]);
            if (hf < threshold) {
                ++count;
            }
        }

        // Second pass — collect
        borrowers = new address[](count);
        healthFactors = new uint256[](count);
        uint256 idx;
        for (uint256 i; i < allBorrowers.length; ++i) {
            uint256 hf = loanManager.getHealthFactor(allBorrowers[i]);
            if (hf < threshold) {
                borrowers[idx] = allBorrowers[i];
                healthFactors[idx] = hf;
                ++idx;
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────
    //  Stress testing / simulation
    // ──────────────────────────────────────────────────────────────────

    /// @notice Simulate the impact of a price change for a single token.
    ///         Returns stress results for all active borrowers using that token as collateral.
    function simulatePriceImpact(address token, uint256 newPrice)
        public
        view
        returns (StressResult[] memory)
    {
        address[] memory allBorrowers = loanManager.getActiveBorrowers();

        // First pass — count affected borrowers
        uint256 count;
        for (uint256 i; i < allBorrowers.length; ++i) {
            Loan memory loan = loanManager.getLoan(allBorrowers[i]);
            if (loan.active && loan.collateralToken == token) {
                ++count;
            }
        }

        StressResult[] memory results = new StressResult[](count);
        uint256 idx;

        for (uint256 i; i < allBorrowers.length; ++i) {
            Loan memory loan = loanManager.getLoan(allBorrowers[i]);
            if (!loan.active || loan.collateralToken != token) continue;

            results[idx] = _stressTestSinglePrice(allBorrowers[i], loan, newPrice);
            ++idx;
        }

        return results;
    }

    function _stressTestSinglePrice(
        address borrower,
        Loan memory loan,
        uint256 newPrice
    ) internal view returns (StressResult memory result) {
        uint256 debt = InterestAccrual.getOutstandingDebt(loan);
        uint8 decimals = priceOracle.getDecimals(loan.collateralToken);
        uint256 threshold = collateralManager.getCollateralInfo(loan.collateralToken).liquidationThreshold;
        uint256 currentPrice = priceOracle.getPrice(loan.collateralToken);

        uint256 currentCV = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, currentPrice, decimals);
        uint256 stressedCV = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, newPrice, decimals);

        result.borrower = borrower;
        result.currentHealthFactor = HealthFactor.calculateHealthFactor(currentCV, debt, threshold);
        result.stressedHealthFactor = HealthFactor.calculateHealthFactor(stressedCV, debt, threshold);
        result.wouldBeLiquidatable = HealthFactor.isLiquidatable(result.stressedHealthFactor);
    }

    /// @notice Simulate a market-wide crash: all collateral prices drop by `dropPercentageBps`.
    /// @param dropPercentageBps e.g., 3000 = 30% drop.
    function simulateMarketCrash(uint256 dropPercentageBps)
        external
        view
        returns (StressResult[] memory)
    {
        address[] memory allBorrowers = loanManager.getActiveBorrowers();

        StressResult[] memory results = new StressResult[](allBorrowers.length);
        uint256 count;

        for (uint256 i; i < allBorrowers.length; ++i) {
            results[count] = _stressTestBorrower(allBorrowers[i], dropPercentageBps);
            if (results[count].borrower != address(0)) {
                ++count;
            }
        }

        // Trim results array
        assembly {
            mstore(results, count)
        }
        return results;
    }

    function _stressTestBorrower(
        address borrower,
        uint256 dropBps
    ) internal view returns (StressResult memory result) {
        Loan memory loan = loanManager.getLoan(borrower);
        if (!loan.active) return result; // borrower == address(0) signals skip

        uint256 debt = InterestAccrual.getOutstandingDebt(loan);
        uint8 decimals = priceOracle.getDecimals(loan.collateralToken);
        uint256 threshold = collateralManager.getCollateralInfo(loan.collateralToken).liquidationThreshold;

        uint256 currentPrice = priceOracle.getPrice(loan.collateralToken);
        uint256 stressedPrice = currentPrice * (BPS - dropBps) / BPS;

        uint256 currentCV = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, currentPrice, decimals);
        uint256 stressedCV = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, stressedPrice, decimals);

        result.borrower = borrower;
        result.currentHealthFactor = HealthFactor.calculateHealthFactor(currentCV, debt, threshold);
        result.stressedHealthFactor = HealthFactor.calculateHealthFactor(stressedCV, debt, threshold);
        result.wouldBeLiquidatable = HealthFactor.isLiquidatable(result.stressedHealthFactor);
    }

    // ──────────────────────────────────────────────────────────────────
    //  Trigger warnings (callable externally to emit events)
    // ──────────────────────────────────────────────────────────────────

    /// @notice Scan all active loans and emit warning events for at-risk positions.
    ///         Returns the number of warnings emitted.
    function emitRiskWarnings() external returns (uint256 warnings, uint256 liquidatable) {
        address[] memory allBorrowers = loanManager.getActiveBorrowers();
        uint256 total = allBorrowers.length;

        for (uint256 i; i < total; ++i) {
            RiskAssessment memory assessment = assessRisk(allBorrowers[i]);
            if (!assessment.isLiquidatable && !assessment.isWarning) continue;

            uint256 level;
            if (assessment.isLiquidatable) {
                level = 3; // Critical — liquidatable
                ++liquidatable;
            } else if (assessment.healthFactor < criticalThreshold) {
                level = 2; // Critical warning
            } else {
                level = 1; // Warning
            }

            emit RiskWarning(allBorrowers[i], assessment.healthFactor, level);
            ++warnings;
        }

        emit BatchRiskAssessment(total, warnings, liquidatable);
    }
}
