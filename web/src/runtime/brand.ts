import type { Instance } from '@/domain/types';

const TILE = '<rect width="32" height="32" rx="9" fill="INK"/>';

const SHAPE =
  '<path transform="translate(16 16) scale(0.14) translate(-148 -118)" d="M128 128 A20 20 0 0 1 168 128 A40 40 0 0 1 88 128 A60 60 0 0 1 208 128" fill="none" stroke="ORANGE" stroke-width="30" stroke-linecap="round"/>';

const paint = (svg: string, ink: string, orange: string) =>
  svg.replaceAll('INK', ink).replaceAll('ORANGE', orange);

const svg = (ink: string, orange: string, attrs = '') =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"${attrs}>${paint(TILE + SHAPE, ink, orange)}</svg>`;

const HEARTH = {
  name: 'Hearth',
  domain: 'hearth.social',
  line: 'A forum, chat and voice home for your community.',
  mark: svg('var(--color-ink)', 'var(--hue-orange)', ' class="logo__mark" aria-hidden="true"'),
  icon: 'data:image/svg+xml,' + encodeURIComponent(svg('#1d2433', '#f08a24')),
} as const;

export type Brand = {
  readonly name: string;
  readonly mark: string;
  readonly icon: string;
};

export function brandFor(instance: Pick<Instance, 'name' | 'logo' | 'icon'>): Brand {
  return {
    name: instance.name,
    mark: instance.logo
      ? `<img class="logo__mark" src="${instance.logo}" alt="" decoding="async">`
      : HEARTH.mark,
    icon: instance.icon ?? HEARTH.icon,
  };
}
