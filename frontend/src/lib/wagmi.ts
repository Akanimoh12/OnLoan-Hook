import { http, createConfig, injected } from 'wagmi';
import { unichain, unichainTestnet } from '@/lib/chains';

export const config = createConfig({
  chains: [unichainTestnet, unichain],
  connectors: [injected()],
  transports: {
    [unichainTestnet.id]: http(),
    [unichain.id]: http(),
  },
});
