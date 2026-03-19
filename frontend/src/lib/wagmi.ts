import { http, createConfig, injected } from 'wagmi';
import { unichain, unichainTestnet } from '@/lib/chains';

const testnetRpc = import.meta.env.VITE_RPC_URL_TESTNET as string | undefined;
const mainnetRpc = import.meta.env.VITE_RPC_URL_MAINNET as string | undefined;

export const config = createConfig({
  chains: [unichainTestnet, unichain],
  connectors: [injected()],
  transports: {
    [unichainTestnet.id]: http(testnetRpc || 'https://sepolia.unichain.org'),
    [unichain.id]: http(mainnetRpc || 'https://mainnet.unichain.org'),
  },
});
