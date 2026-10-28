import type { SelectOption } from '@/design-system';

export const REASONS: SelectOption<string>[] = [
  'Spam',
  'Not kind',
  'Off topic',
  'Duplicate',
  'Personal information',
].map((r) => ({ value: r, label: r }));

export const DEFAULT_REASON = 'Spam';
