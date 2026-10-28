import { WebHaptics, type HapticInput } from 'web-haptics';
import type { CueName } from './sounds';

export const TAP: HapticInput = [{ duration: 25, intensity: 0.6 }];

// Only cues that answer something you did, or that change the room for you, are felt
const FELT: Partial<Record<CueName, HapticInput>> = {
  join: 'success',
  live: 'success',
  leave: TAP,
  mute: TAP,
  unmute: TAP,
  invited: 'nudge',
  end: 'nudge',
  recordStart: 'nudge',
  recordStop: TAP,
  shareStart: TAP,
  cleared: TAP,
  error: 'error',
};

let haptics: WebHaptics | null = null;
let enabled = true;

// A phone or tablet, where a buzz means something, rather than a desktop with a touchscreen
const touchDevice = () =>
  typeof window !== 'undefined' && window.matchMedia('(pointer: coarse)').matches;

export function setHapticsEnabled(on: boolean) {
  enabled = on;
}

export function feel(input: HapticInput) {
  if (!enabled || !touchDevice()) return;

  haptics ??= new WebHaptics();
  void haptics.trigger(input);
}

export function feelCue(name: CueName) {
  const input = FELT[name];

  if (input) feel(input);
}
