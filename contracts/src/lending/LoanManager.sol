// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Loan} from "../types/LoanTypes.sol";
import {InterestAccrual} from "../libraries/InterestAccrual.sol";
import {HealthFactor} from "../libraries/HealthFactor.sol";
import {CollateralValuation} from "../libraries/CollateralValuation.sol";
import {Events} from "../libraries/Events.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";
import {LoanAlreadyExists, InvalidDuration, AboveMaximumLTV, LoanNotActive, RepaymentExceedsDebt} from "../types/Errors.sol";

contract LoanManager is ILoanManager, Ownable {
    mapping(address => Loan) public loans;
    mapping(address => PoolId) public borrowerPool;
    uint256 public totalActiveLoans;
    address[] public activeBorrowers;

    ILendingPool public lendingPool;
    ICollateralManager public collateralManager;
    IPriceOracle public priceOracle;
    address public hook;
    address public liquidationEngine;

    error NotHook();
    error NotLiquidationEngine();

    modifier onlyHook() {
        if (msg.sender != hook) revert NotHook();
        _;
    }

    modifier onlyLiquidationEngine() {
        if (msg.sender != liquidationEngine) revert NotLiquidationEngine();
        _;
    }

    constructor(
        address _lendingPool,
        address _collateralManager,
        address _priceOracle
    ) Ownable(msg.sender) {
        lendingPool = ILendingPool(_lendingPool);
        collateralManager = ICollateralManager(_collateralManager);
        priceOracle = IPriceOracle(_priceOracle);
    }

    function setHook(address _hook) external onlyOwner {
        hook = _hook;
    }

    function setLiquidationEngine(address _engine) external onlyOwner {
        liquidationEngine = _engine;
    }

    function createLoan(
        address borrower,
        PoolId poolId,
        address collateralToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 duration
    ) external onlyHook returns (Loan memory) {
        if (loans[borrower].active) revert LoanAlreadyExists(borrower);

        {
            uint256 minDur = lendingPool.getPoolConfig(poolId).minLoanDuration;
            uint256 maxDur = lendingPool.getPoolConfig(poolId).maxLoanDuration;
            if (duration < minDur || duration > maxDur) revert InvalidDuration(duration);
        }

        {
            uint256 price = priceOracle.getPrice(collateralToken);
            uint8 decimals = priceOracle.getDecimals(collateralToken);
            uint256 collateralValue = CollateralValuation.getCollateralValueUSD(collateralAmount, price, decimals);
            uint256 maxLTV = collateralManager.getCollateralInfo(collateralToken).maxLTV;
            uint256 maxBorrowable = HealthFactor.calculateMaxBorrowable(collateralValue, maxLTV);
            if (borrowAmount > maxBorrowable) revert AboveMaximumLTV(borrowAmount, maxBorrowable);
        }

        collateralManager.lockCollateral(borrower, collateralToken, collateralAmount);
        lendingPool.recordBorrow(poolId, borrowAmount);

        uint256 currentRate = lendingPool.getCurrentInterestRate(poolId);

        Loan memory loan = Loan({
            borrower: borrower,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            borrowedAmount: borrowAmount,
            accruedInterest: 0,
            interestRateAtOrigination: currentRate,
            startTime: block.timestamp,
            lastAccrualTime: block.timestamp,
            duration: duration,
            active: true
        });

        loans[borrower] = loan;
        borrowerPool[borrower] = poolId;
        activeBorrowers.push(borrower);
        totalActiveLoans++;

        emit Events.LoanCreated(borrower, poolId, collateralAmount, borrowAmount, currentRate, duration);

        return loan;
    }

    function accrueInterest(address borrower) public {
        Loan storage loan = loans[borrower];
        if (!loan.active) return;
        uint256 newInterest = InterestAccrual.accrueInterest(loan);
        if (newInterest > 0) {
            loan.accruedInterest += newInterest;
            loan.lastAccrualTime = block.timestamp;
            emit Events.InterestAccrued(borrower, newInterest, loan.accruedInterest);
        }
    }

    function repay(address borrower, uint256 amount) external onlyHook returns (uint256 remaining) {
        Loan storage loan = loans[borrower];
        if (!loan.active) revert LoanNotActive(borrower);

        accrueInterest(borrower);

        uint256 totalDebt = loan.borrowedAmount + loan.accruedInterest;
        if (amount > totalDebt) revert RepaymentExceedsDebt(amount, totalDebt);

        uint256 interestPaid;
        uint256 principalPaid;

        if (amount <= loan.accruedInterest) {
            interestPaid = amount;
            loan.accruedInterest -= amount;
        } else {
            interestPaid = loan.accruedInterest;
            principalPaid = amount - interestPaid;
            loan.accruedInterest = 0;
            loan.borrowedAmount -= principalPaid;
        }

        PoolId poolId = borrowerPool[borrower];
        lendingPool.recordRepayment(poolId, principalPaid, interestPaid);

        remaining = loan.borrowedAmount + loan.accruedInterest;

        if (remaining == 0) {
            loan.active = false;
            collateralManager.unlockCollateral(borrower, loan.collateralToken, loan.collateralAmount);
            _removeActiveBorrower(borrower);
            totalActiveLoans--;
            emit Events.LoanFullyRepaid(borrower, poolId);
            emit Events.CollateralReleased(borrower, loan.collateralToken, loan.collateralAmount);
        } else {
            emit Events.LoanRepaid(borrower, principalPaid, interestPaid, remaining);
        }
    }

    function markLoanLiquidated(address borrower) external onlyLiquidationEngine {
        Loan storage loan = loans[borrower];
        loan.active = false;
        _removeActiveBorrower(borrower);
        totalActiveLoans--;
    }

    function getLoan(address borrower) external view returns (Loan memory) {
        return loans[borrower];
    }

    function getOutstandingDebt(address borrower) external view returns (uint256) {
        return InterestAccrual.getOutstandingDebt(loans[borrower]);
    }

    function getHealthFactor(address borrower) external view returns (uint256) {
        Loan memory loan = loans[borrower];
        if (!loan.active) return type(uint256).max;
        uint256 debt = InterestAccrual.getOutstandingDebt(loan);
        uint256 price = priceOracle.getPrice(loan.collateralToken);
        uint8 decimals = priceOracle.getDecimals(loan.collateralToken);
        uint256 collateralValue = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, price, decimals);
        uint256 threshold = collateralManager.getCollateralInfo(loan.collateralToken).liquidationThreshold;
        return HealthFactor.calculateHealthFactor(collateralValue, debt, threshold);
    }

    function isLoanActive(address borrower) external view returns (bool) {
        return loans[borrower].active;
    }

    function isLoanExpired(address borrower) external view returns (bool) {
        Loan memory loan = loans[borrower];
        if (!loan.active) return false;
        return block.timestamp > loan.startTime + loan.duration;
    }

    function getActiveBorrowerCount() external view returns (uint256) {
        return activeBorrowers.length;
    }

    function getActiveBorrowers() external view returns (address[] memory) {
        return activeBorrowers;
    }

    function getBorrowerPool(address borrower) external view returns (PoolId) {
        return borrowerPool[borrower];
    }

    function _removeActiveBorrower(address borrower) internal {
        for (uint256 i; i < activeBorrowers.length; ++i) {
            if (activeBorrowers[i] == borrower) {
                activeBorrowers[i] = activeBorrowers[activeBorrowers.length - 1];
                activeBorrowers.pop();
                break;
            }
        }
    }
}
