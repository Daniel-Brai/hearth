import type { LiveRoomView, RoomSession } from './live-room-view';

export function audibleSpeakers(session: RoomSession): Set<string> {
  const quiet = new Set([...session.muted, ...session.locked]);
  return new Set(session.speaking.filter((id) => !quiet.has(id)));
}

/** Your own ring follows your microphone, not the server */
export const youSpeaking = (view: LiveRoomView, session: RoomSession): boolean =>
  !view.muted && (session.selfTalking || (!!view.me && session.speaking.includes(view.me)));

/** Everyone else on stage, which in an open room is everyone in it */
export const stagePeople = (view: LiveRoomView, session: RoomSession): readonly string[] =>
  view.open ? [...new Set([...session.speakers, ...session.listeners])] : session.speakers;

export function stageTalkers(view: LiveRoomView, session: RoomSession) {
  const speaking = audibleSpeakers(session);
  const you =
    view.onStage && view.me ? [{ id: view.me, speaking: youSpeaking(view, session) }] : [];

  return [...you, ...stagePeople(view, session).map((id) => ({ id, speaking: speaking.has(id) }))];
}
