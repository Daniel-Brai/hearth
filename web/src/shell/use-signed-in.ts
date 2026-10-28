import { useGateway } from '@/app/gateway-context';
import { onServer } from '@/data/env';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';

/** The server render has no session so the browser checks under its own key */
export function useSignedIn(): boolean {
  const gateway = useGateway();
  useLoad(() => gateway.load.session(), onServer ? 'session' : 'session:browser');

  return useAppState((state) => state.me !== null);
}

export function useSignedInNow(): boolean {
  const gateway = useGateway();
  useLoad(() => gateway.load.session(), 'session');

  return useAppState((state) => state.me !== null);
}
