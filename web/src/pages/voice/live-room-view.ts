import { useAppState } from '@/data/store';
import { canDo, recordingOn, transcriptionOn } from '@/domain/selectors';
import { keyOf } from '@/runtime/keys';
import type { useRoomSession } from './voice-session';

export type RoomSession = ReturnType<typeof useRoomSession>;

export function useLiveRoomView(cid: string, rid: string) {
  return useAppState((state) => {
    const room = state.communities[cid]!.voice.find((v) => v.id === rid)!;
    const asHost = room.host === state.me || !!state.live.hostTools;

    return {
      me: state.me,
      role: state.live.role,
      onStage: room.mode === 'open' || state.live.role !== 'listener',
      muted: state.live.muted,
      open: room.mode === 'open',
      topic: room.topic,
      host: room.host,
      postId: room.postId,
      postTitle: state.posts.find((p) => p.id === room.postId)?.title ?? null,
      total: room.listeners,
      asHost,
      canRecord: recordingOn(state) && (asHost || canDo(state, cid, 'voice-recording.create')),
      captionsAllowed: transcriptionOn(state),
      captions: transcriptionOn(state) && state.settings.captions,
      muteKey: keyOf('voice_mute', state.settings.keys),
      audioBlocked: !!state.live.audioBlocked,
      connection: state.live.connection ?? null,
    };
  });
}

export type LiveRoomView = ReturnType<typeof useLiveRoomView>;
