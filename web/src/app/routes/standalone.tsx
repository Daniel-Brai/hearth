import { StandaloneShell } from '@/shell/StandaloneShell';
import { ClientOnlyFallback } from './client-only';
import { clientOnlyLoader } from './client-only-loader';

export const clientLoader = clientOnlyLoader;

export const HydrateFallback = ClientOnlyFallback;

export default StandaloneShell;
