import type { Attachment } from '@/domain/types';

/** Files the text doesn't already show inline */
export const looseFiles = (files: readonly Attachment[] | undefined, text: string) =>
  (files ?? []).filter((f) => !text.includes(`attachment:${f.id}`));
