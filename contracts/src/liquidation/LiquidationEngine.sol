// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Loan, CollateralInfo} from "../types/LoanTypes.sol";
import {HealthFactor} from "../libraries/HealthFactor.sol";
import {InterestAccrual} from "../libraries/InterestAccrual.sol";
import {CollateralValuation} from "../libraries/CollateralValuation.sol";
import {LoanMath} from "../libraries/LoanMath.sol";
import {Events} from "../libraries/Events.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {ILiquidationEngine} from "../interfaces/ILiquidationEngine.sol";
import {LoanNotActive, HealthFactorAboveThreshold} from "../types/Errors.sol";

contract LiquidationEngine is ILiquidationEngine, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => bool) public authorizedLiquidators;
    ILoanManager public loanManager;
    ICollateralManager public collateralManager;
    ILendingPool public lendingPool;
    IPriceOracle public priceOracle;

    error NotAuthorizedLiquidator();

    modifier onlyAuthorizedLiquidator() {
        if (!authorizedLiquidators[msg.sender]) revert NotAuthorizedLiquidator();
        _;
    }

    constructor(
        address _loanManager,
        address _collateralManager,
        address _lendingPool,
        address _priceOracle
    ) Ownable(msg.sender) {
        loanManager = ILoanManager(_loanManager);
        collateralManager = ICollateralManager(_collateralManager);
        lendingPool = ILendingPool(_lendingPool);
        priceOracle = IPriceOracle(_priceOracle);
    }

    function setAuthorizedLiquidator(address liquidator, bool authorized) external onlyOwner {
        authorizedLiquidators[liquidator] = authorized;
        emit Events.AuthorizedLiquidatorSet(liquidator, authorized);
    }

    function liquidateLoan(address borrower) external onlyAuthorizedLiquidator nonReentrant {
        Loan memory loan = loanManager.getLoan(borrower);
        if (!loan.active) revert LoanNotActive(borrower);

        loanManager.accrueInterest(borrower);
        loan = loanManager.getLoan(borrower);

        uint256 debt = loan.borrowedAmount + loan.accruedInterest;
        uint256 price = priceOracle.getPrice(loan.collateralToken);
        uint8 decimals = priceOracle.getDecimals(loan.collateralToken);
        uint256 collateralValue = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, price, decimals);
        CollateralInfo memory info = collateralManager.getCollateralInfo(loan.collateralToken);
        uint256 hf = HealthFactor.calculateHealthFactor(collateralValue, debt, info.liquidationThreshold);
        bool expired = block.timestamp > loan.startTime + loan.duration;

        if (!HealthFactor.isLiquidatable(hf) && !expired) revert HealthFactorAboveThreshold(hf);

        uint256 collateralSeized = loan.collateralAmount;
        uint256 bonus = (collateralSeized * info.liquidationBonus) / LoanMath.BPS;

        collateralManager.seizeCollateral(borrower, loan.collateralToken, collateralSeized);

        PoolId poolId = loanManager.getBorrowerPool(borrower);
        lendingPool.recordRepayment(poolId, loan.borrowedAmount, loan.accruedInterest);

        loanManager.markLoanLiquidated(borrower);

        emit Events.LoanLiquidated(borrower, msg.sender, collateralSeized, debt, bonus);
    }

    function isLiquidatable(address borrower) external view returns (bool) {
        Loan memory loan = loanManager.getLoan(borrower);
        if (!loan.active) return false;
        uint256 debt = InterestAccrual.getOutstandingDebt(loan);
        uint256 price = priceOracle.getPrice(loan.collateralToken);
        uint8 decimals = priceOracle.getDecimals(loan.collateralToken);
        uint256 collateralValue = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, price, decimals);
        uint256 threshold = collateralManager.getCollateralInfo(loan.collateralToken).liquidationThreshold;
        uint256 hf = HealthFactor.calculateHealthFactor(collateralValue, debt, threshold);
        bool expired = block.timestamp > loan.startTime + loan.duration;
        return HealthFactor.isLiquidatable(hf) || expired;
    }

    function getLiquidationInfo(address borrower)
        external
        view
        returns (uint256 healthFactor, uint256 debtUSD, uint256 collateralUSD, uint256 bonus)
    {
        Loan memory loan = loanManager.getLoan(borrower);
        debtUSD = InterestAccrual.getOutstandingDebt(loan);
        uint256 price = priceOracle.getPrice(loan.collateralToken);
        uint8 decimals = priceOracle.getDecimals(loan.collateralToken);
        collateralUSD = CollateralValuation.getCollateralValueUSD(loan.collateralAmount, price, decimals);
        CollateralInfo memory info = collateralManager.getCollateralInfo(loan.collateralToken);
        healthFactor = HealthFactor.calculateHealthFactor(collateralUSD, debtUSD, info.liquidationThreshold);
        bonus = (loan.collateralAmount * info.liquidationBonus) / LoanMath.BPS;
    }
}
