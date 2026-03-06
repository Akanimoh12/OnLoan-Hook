import { http, createConfig } from 'wagmi';
import { unichain } from '@/lib/chains';

export const config = createConfig({
  chains: [unichain],
  transports: {
    [unichain.id]: http(),
  },
});
