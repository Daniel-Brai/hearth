import { StrictMode, startTransition } from 'react';
import { hydrateRoot } from 'react-dom/client';
import { HydratedRouter } from 'react-router/dom';
import { AppProviders } from '@/app/AppProviders';
import { HYDRATION_KEY, type Hydration } from '@/app/hydration';
import { createRuntime } from '@/app/runtime';
import { setStore } from '@/data/store';
import { browserLoads } from '@/data/use-load';

declare global {
  interface Window {
    [HYDRATION_KEY]?: Hydration;
  }
}

const hydration = window[HYDRATION_KEY] ?? null;
const runtime = await createRuntime(hydration?.state ?? null);
const loads = browserLoads();

setStore(runtime.store);

loads.seed(hydration?.loaded ?? []);

startTransition(() => {
  hydrateRoot(
    document,
    <StrictMode>
      <AppProviders
        runtime={runtime}
        loads={loads}
        request={{
          origin: hydration?.origin ?? window.location.origin,
          zone: hydration?.zone ?? 'UTC',
          setStatus: () => undefined,
        }}
      >
        <HydratedRouter />
      </AppProviders>
    </StrictMode>,
  );
});

// The service worker keeps visited screens and the app's code for when the network drops
if (import.meta.env.PROD && 'serviceWorker' in navigator)
  window.addEventListener('load', () => void navigator.serviceWorker.register('/sw.js'));
