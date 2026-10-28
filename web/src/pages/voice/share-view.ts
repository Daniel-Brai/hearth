export type ShareLayout = 'none' | 'focus' | 'grid';

/** gridFor is the sharer switched back to the grid so a new share opens in focus */
// The one sharing sees their screen the same way everyone watching does
export function shareLayout(
  share: { readonly by: string } | null,
  gridFor: string | null,
): ShareLayout {
  if (!share) return 'none';
  return gridFor === share.by ? 'grid' : 'focus';
}

export const QUICK_REACTIONS = [':+1:', ':heart:', ':joy:', ':tada:', ':clap:'] as const;
