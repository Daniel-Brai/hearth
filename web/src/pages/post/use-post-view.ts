import { useAppState } from '@/data/store';
import {
  canDo,
  community,
  displayName,
  isMod,
  kindInfo,
  liveOnPost,
  post as selectPost,
  recordingFor,
  reportsOn,
  shortName,
  takesAnswers,
  transcriptFor,
  transcriptionOn,
  voiceOn,
} from '@/domain/selectors';
import { keyOf } from '@/runtime/keys';

export function usePostView(id: string) {
  return useAppState((state) => {
    const p = selectPost(state, id)!;
    const c = community(state, p.c)!;
    const live = liveOnPost(state, p);
    const transcribed = transcriptionOn(state);
    const transcript = transcribed ? transcriptFor(state, p.id) : null;

    return {
      me: state.me,
      communityName: c.name,
      communityImage: c.banner ?? c.logo,
      joined: c.joined,
      kindHue: kindInfo(state, p.c, p.kind).hue,
      live: live ? { id: live.id, listeners: live.listeners, mode: live.mode ?? 'stage' } : null,
      transcript: transcript
        ? { id: transcript.id, room: transcript.room, duration: transcript.duration }
        : null,
      transcribed,
      voice: voiceOn(state),
      recorded: !!recordingFor(state, p.id),
      canPin: canDo(state, p.c, 'post.pin'),
      canBan: canDo(state, p.c, 'member.ban'),
      mod: isMod(state, p.c),
      reports: reportsOn(state, p.c),
      canAnswer:
        takesAnswers(state, p) && (p.author === state.me || canDo(state, p.c, 'post.answer')),
      replyKey: keyOf('post_reply', state.settings.keys),
      authorShort: shortName(state, p.author),
      authorName: displayName(state, p.author),
    };
  });
}

export type PostViewData = ReturnType<typeof usePostView>;
