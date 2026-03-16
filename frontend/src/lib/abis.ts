import { type Abi } from 'viem';

import OnLoanHookAbiRaw from '@/abis/OnLoanHook.json';
import LendingPoolAbiRaw from '@/abis/LendingPool.json';
import LoanManagerAbiRaw from '@/abis/LoanManager.json';
import CollateralManagerAbiRaw from '@/abis/CollateralManager.json';
import PriceOracleAbiRaw from '@/abis/PriceOracle.json';
import PoolManagerAbiRaw from '@/abis/PoolManager.json';

export const OnLoanHookAbi = OnLoanHookAbiRaw as Abi;
export const LendingPoolAbi = LendingPoolAbiRaw as Abi;
export const LoanManagerAbi = LoanManagerAbiRaw as Abi;
export const CollateralManagerAbi = CollateralManagerAbiRaw as Abi;
export const PriceOracleAbi = PriceOracleAbiRaw as Abi;
export const PoolManagerAbi = PoolManagerAbiRaw as Abi;
