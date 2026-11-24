import type { IconName } from '@/design-system';
import type { VoiceMode } from '@/domain/types';

type ModeInfo = {
  readonly id: VoiceMode;
  readonly label: string;
  readonly icon: IconName;
  readonly text: string;
};

export const VOICE_MODES = [
  {
    id: 'open',
    label: 'Open',
    icon: 'mic',
    text: 'Anyone here can talk. You join muted and unmute when ready.',
  },
  {
    id: 'stage',
    label: 'Stage',
    icon: 'hand',
    text: 'Speakers talk on stage. Raise your hand to be invited up.',
  },
] as const satisfies readonly ModeInfo[];

export const modeInfo = (mode: VoiceMode): ModeInfo =>
  VOICE_MODES.find((m) => m.id === mode) ?? VOICE_MODES[0];
