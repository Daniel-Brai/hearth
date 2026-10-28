import { Protected } from '@/shell/Protected';
import { ClientOnlyFallback } from './client-only';
import { clientOnlyLoader } from './client-only-loader';

export const clientLoader = clientOnlyLoader;

export const HydrateFallback = ClientOnlyFallback;

export default Protected;
