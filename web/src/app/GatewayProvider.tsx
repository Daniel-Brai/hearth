import type { ReactNode } from 'react';
import type { HearthGateway } from '@/data/gateway';
import { GatewayContext } from './gateway-context';

export function GatewayProvider({
  gateway,
  children,
}: {
  readonly gateway: HearthGateway;
  readonly children: ReactNode;
}) {
  return <GatewayContext.Provider value={gateway}>{children}</GatewayContext.Provider>;
}
