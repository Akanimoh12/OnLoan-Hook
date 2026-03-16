import { create } from 'zustand';

interface AppState {
  poolId: `0x${string}` | null;
  setPoolId: (id: `0x${string}`) => void;
}

/**
 * Global application state store.
 * Kept minimal as Wagmi/TanStack takes care of remote data & wallet state.
 */
export const useAppStore = create<AppState>((set) => ({
  poolId: null,
  setPoolId: (id) => set({ poolId: id }),
}));
