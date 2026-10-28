import type { AppState } from '@/domain/app-state';
import { findRoom } from '@/domain/selectors';
import { lexMarkdown } from './markdown';

export function extractTags(
  state: AppState,
  text: string,
  community: string | null | undefined,
): string[] {
  const out = new Set<string>();

  for (const name of lexMarkdown(text).refs) {
    if (!findRoom(state, name, community)) out.add(name.toLowerCase());
  }

  return [...out];
}
