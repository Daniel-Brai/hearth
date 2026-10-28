import { isHex } from '@/domain/format';
import { ICONS, type IconName } from '@/design-system';

export const KIND_HUES = [
  'blue',
  'violet',
  'pink',
  'red',
  'orange',
  'yellow',
  'green',
  'aqua',
  'ink',
] as const;

const KIND_ICON_NAMES = [
  'question',
  'chat',
  'sparkles',
  'megaphone',
  'scroll',
  'briefcase',
  'bug',
  'bulb',
  'shapes',
  'flag',
  'star',
  'calendar',
  'code',
  'image',
  'video',
  'music',
  'link',
  'tag',
  'globe',
  'shield',
  'key',
  'flame',
  'map',
  'users',
  'lock',
  'pin',
  'helpful',
  'mic',
  'book',
];

export const asIconName = (name: string): IconName | null =>
  name in ICONS ? (name as IconName) : null;

export const KIND_ICONS: IconName[] = KIND_ICON_NAMES.map(asIconName).filter((n) => n !== null);

const FALLBACK_HEX = '#888888';

const toHex = (n: number) => n.toString(16).padStart(2, '0');

export function hexFor(hue: string): string {
  if (isHex(hue) && hue.length === 7) return hue;

  const probe = document.createElement('span');

  probe.style.color = `var(--hue-${hue})`;
  document.body.appendChild(probe);

  const color = getComputedStyle(probe).color;

  probe.remove();

  const context = document.createElement('canvas').getContext('2d');

  if (!context) return FALLBACK_HEX;

  context.fillStyle = color;
  context.fillRect(0, 0, 1, 1);

  const [r = 0, g = 0, b = 0] = context.getImageData(0, 0, 1, 1).data;

  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}
