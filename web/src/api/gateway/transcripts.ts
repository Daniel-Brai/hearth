import type { HearthGateway, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import { communityShow } from '@/generated/api/communities/communities';
import { transcriptShow, transcriptUpdateSegment } from '@/generated/api/voice/voice';
import { toPerson, toRecording, toTranscript } from '../mappers';
import type { GatewayContext } from './context';
import { call, failed } from './context';

export function createTranscriptsGateway(ctx: GatewayContext) {
  const learnCommunity = async (id: string) => {
    if (ctx.communitySlugs.has(id)) return;

    const answer = await call(() => communityShow(id));
    if (answer.status === 200) ctx.rememberCommunity(answer.data.community, answer.data);
  };

  const load = {
    transcript: async (sessionId: string): Promise<Result> => {
      await ctx.sessionLoaded;

      const answer = await call(() => transcriptShow(sessionId));

      if (answer.status !== 200) return failed(answer);

      const t = answer.data;

      await learnCommunity(t.community_id);

      const cid = ctx.communitySlugs.get(t.community_id);

      if (!cid) return fail("That community couldn't be loaded.");

      const rid = ctx.roomsById.get(t.room_id)?.slug ?? '';

      ctx.store.set((state) => {
        for (const p of t.people) state.people[p.id] ??= toPerson(p);
        state.recordings[t.recording.id] = toRecording(t.recording, cid, rid, t.room_name, {
          postId: t.post_id ?? undefined,
        });
        state.transcripts[t.session_id] = toTranscript(t, cid);
      });

      // The page fills in by itself once a transcript still being written is done
      if (t.status === 'queued' || t.status === 'transcribing')
        ctx.watch(
          `community:${t.community_id}`,
          (realtime, topic) =>
            realtime.onPush(topic, 'TranscriptReady', (e) => {
              if (e.session_id === sessionId) void load.transcript(sessionId);
            }),
          `transcript:${sessionId}`,
        );

      return ok(undefined);
    },
  } satisfies Partial<HearthGateway['load']>;

  const editLine = async (sessionId: string, lineId: string, text: string): Promise<Result> => {
    const answer = await call(() => transcriptUpdateSegment(lineId, { text }));

    if (answer.status !== 200) return failed(answer);

    ctx.store.set((state) => {
      const line = state.transcripts[sessionId]?.lines.find((l) => l.id === lineId);
      if (line) line.text = answer.data.text;
    });

    return ok(undefined);
  };

  return { load, editLine };
}
