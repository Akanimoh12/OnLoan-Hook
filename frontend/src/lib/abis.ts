import { type Abi } from 'viem';

import OnLoanHookAbiRaw from '@/abis/OnLoanHook.json';
import LendingPoolAbiRaw from '@/abis/LendingPool.json';
import LoanManagerAbiRaw from '@/abis/LoanManager.json';
import CollateralManagerAbiRaw from '@/abis/CollateralManager.json';
import PriceOracleAbiRaw from '@/abis/PriceOracle.json';
import PoolManagerAbiRaw from '@/abis/PoolManager.json';
import RiskEngineAbiRaw from '@/abis/RiskEngine.json';
import InterestRateModelAbiRaw from '@/abis/InterestRateModel.json';
import LiquidationEngineAbiRaw from '@/abis/LiquidationEngine.json';
import MockERC20AbiRaw from '@/abis/MockERC20.json';

export const OnLoanHookAbi = OnLoanHookAbiRaw as Abi;
export const LendingPoolAbi = LendingPoolAbiRaw as Abi;
export const LoanManagerAbi = LoanManagerAbiRaw as Abi;
export const CollateralManagerAbi = CollateralManagerAbiRaw as Abi;
export const PriceOracleAbi = PriceOracleAbiRaw as Abi;
export const PoolManagerAbi = PoolManagerAbiRaw as Abi;
export const RiskEngineAbi = RiskEngineAbiRaw as Abi;
export const InterestRateModelAbi = InterestRateModelAbiRaw as Abi;
export const LiquidationEngineAbi = LiquidationEngineAbiRaw as Abi;
export const MockERC20Abi = MockERC20AbiRaw as Abi;
