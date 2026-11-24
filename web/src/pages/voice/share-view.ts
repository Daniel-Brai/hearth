type ShareLayout = 'none' | 'focus' | 'grid';

/** A share opens in focus until its sharer switches back to the grid */
export function shareLayout(
  share: { readonly by: string } | null,
  gridFor: string | null,
): ShareLayout {
  if (!share) return 'none';

  return gridFor === share.by ? 'grid' : 'focus';
}

export const QUICK_REACTIONS = [':+1:', ':heart:', ':joy:', ':tada:', ':clap:'] as const;
