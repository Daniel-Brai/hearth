import type { RoomSession } from '@/data/voice-session';

export {
  getRoomSession,
  useRoomSession,
  useVoiceSession,
  type RoomSession,
} from '@/data/voice-session';

export const clockLabel = (seconds: number) =>
  String(Math.floor(seconds / 60)).padStart(2, '0') + ':' + String(seconds % 60).padStart(2, '0');

export function unnamedCount(total: number, s: RoomSession, joined: boolean) {
  const named = new Set([...s.speakers, ...s.listeners]).size + (joined ? 1 : 0);

  return Math.max(0, total - named);
}
