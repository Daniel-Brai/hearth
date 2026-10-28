import type { SelectOption } from '@/design-system';
import { routes } from '@/runtime/routes';

export const EXPIRY_OPTIONS: SelectOption<string>[] = [
  { value: '1d', label: '1 day' },
  { value: '7d', label: '7 days' },
  { value: '30d', label: '30 days' },
  { value: 'never', label: 'Never' },
];

export const MAX_OPTIONS: SelectOption<string>[] = [
  { value: '1', label: '1 person' },
  { value: '10', label: '10 people' },
  { value: '50', label: '50 people' },
  { value: 'none', label: 'No limit' },
];

export const DEFAULT_LINK = { expires: '7d', max: '50', role: 'member' } as const;

const EXPIRY_DAYS: Record<string, number> = { '1d': 1, '7d': 7, '30d': 30 };

export function expiryDate(expires: string): string | null {
  const days = EXPIRY_DAYS[expires];

  if (days === undefined) return null;

  const d = new Date();

  d.setDate(d.getDate() + days);

  return d.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' });
}

export type LinkUses = { main: string; sub: string; pct: number };

export function linkUses(uses: number, max: string): LinkUses {
  if (max === 'none') return { main: `${uses} joined`, sub: 'No limit', pct: 0 };

  const limit = parseInt(max, 10);

  return {
    main: `${uses} of ${limit}`,
    sub: `${Math.max(0, limit - uses)} spots left`,
    pct: Math.min(100, Math.round((uses / limit) * 100)),
  };
}

export const joinUrl = (code: string) => window.location.origin + routes.join(code);

export function isEmail(value: string): boolean {
  const parts = value.split('@');

  if (parts.length !== 2 || [...value].some((ch) => ch.trim() === '')) return false;

  const [local, domain] = parts;

  if (!local || !domain) return false;

  const labels = domain.split('.');

  return labels.length >= 2 && labels.every((label) => label.length > 0);
}

export function splitAddresses(text: string): string[] {
  return [...text]
    .map((ch) => (ch === ',' || ch === ';' || ch.trim() === '' ? ' ' : ch))
    .join('')
    .split(' ')
    .map((part) => part.toLowerCase())
    .filter((part) => part.length > 0);
}
