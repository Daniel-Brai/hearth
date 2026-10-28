import type { IconName } from '@/design-system';
import type { VoiceMode } from '@/domain/types';
import type { RoomSession } from '@/data/voice-session';

export {
  getRoomSession,
  useRoomSession,
  useVoiceSession,
  type RoomSession,
} from '@/data/voice-session';

export type ModeInfo = {
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

export const clockLabel = (seconds: number) =>
  String(Math.floor(seconds / 60)).padStart(2, '0') + ':' + String(seconds % 60).padStart(2, '0');

export function unnamedCount(total: number, s: RoomSession, joined: boolean) {
  const named = new Set([...s.speakers, ...s.listeners]).size + (joined ? 1 : 0);

  return Math.max(0, total - named);
}
