import type { ReactNode } from 'react';
import { StoreContext } from '@/data/store';
import { LoadCacheContext, type LoadCache } from '@/data/use-load';
import { GatewayProvider } from './GatewayProvider';
import { RequestContext, type RequestInfo } from './request-context';
import type { Runtime } from './runtime';

export function AppProviders({
  runtime,
  loads,
  request,
  children,
}: {
  readonly runtime: Runtime;
  readonly loads: LoadCache;
  readonly request: RequestInfo;
  readonly children: ReactNode;
}) {
  return (
    <StoreContext value={runtime.store}>
      <LoadCacheContext value={loads}>
        <RequestContext value={request}>
          <GatewayProvider gateway={runtime.gateway}>{children}</GatewayProvider>
        </RequestContext>
      </LoadCacheContext>
    </StoreContext>
  );
}
