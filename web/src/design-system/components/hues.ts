export const HUE_CHOICES = [
  'blue',
  'violet',
  'pink',
  'red',
  'orange',
  'yellow',
  'green',
  'aqua',
] as const;

export type HueChoice = (typeof HUE_CHOICES)[number];
