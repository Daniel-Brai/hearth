import type { HueChoice } from '@/design-system';
import type { Audience } from '@/domain/audience';
import { KIND_LIB } from '@/domain/catalog';

export type Form = {
  name: string;
  tagline: string;
  description: string;
  hue: HueChoice;
  audience: Audience;
  logo: string | null;
  note: string;
};

export const EMPTY: Form = {
  name: '',
  tagline: '',
  description: '',
  hue: 'green',
  audience: 'indexed',
  logo: null,
  note: '',
};

export const kindName = (key: string) =>
  (KIND_LIB as Record<string, { name: string }>)[key]?.name ?? key;
