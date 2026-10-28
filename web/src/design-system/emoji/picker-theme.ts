import type { CSSProperties } from 'react';

const TOKENS = {
  '--rgb-background': '--color-canvas',
  '--rgb-input': '--color-ink-lightest',
  '--rgb-color': '--color-ink',
  '--rgb-accent': '--color-link',
} as const;

/** emoji-mart wants r, g, b triplets so the browser converts each oklch token by painting it on a canvas */
export function pickerThemeStyle(): CSSProperties {
  const canvas = document.createElement('canvas');

  canvas.width = 1;
  canvas.height = 1;

  const context = canvas.getContext('2d', { willReadFrequently: true });

  if (!context) return {};

  const root = getComputedStyle(document.documentElement);
  const style: Record<string, string> = {};

  for (const [variable, token] of Object.entries(TOKENS)) {
    const color = root.getPropertyValue(token).trim();

    if (!color) continue;

    context.clearRect(0, 0, 1, 1);
    context.fillStyle = color;
    context.fillRect(0, 0, 1, 1);

    const [r, g, b] = context.getImageData(0, 0, 1, 1).data;

    style[variable] = `${r}, ${g}, ${b}`;
  }

  return style as CSSProperties;
}
