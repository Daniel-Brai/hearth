import { createContext, useContext } from 'react';
import type { HearthGateway } from '@/data/gateway';

export const GatewayContext = createContext<HearthGateway | null>(null);

export function useGateway(): HearthGateway {
  const g = useContext(GatewayContext);

  if (!g) throw new Error('useGateway needs a GatewayProvider above it');

  return g;
}
