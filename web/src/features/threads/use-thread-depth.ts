import { useMedia } from '@/runtime/use-media';

export function useThreadDepth(): number {
  return useMedia('(min-width: 40rem)') ? 4 : 2;
}
