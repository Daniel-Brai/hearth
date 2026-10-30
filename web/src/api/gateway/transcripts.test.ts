import { describe, expect, it } from 'vitest';
import { at, community, gateway, me, routes, sent, session } from './test-support';

const recording = {
  id: 'rec1',
  session_id: 's1',
  room_id: 'r1',
  community_id: 'c1',
  started_by_id: 'u1',
  status: 'ready',
  failure: null,
  started_at: at,
  ended_at: at,
  duration_ms: 90_000,
  byte_size: 10,
  width: 1280,
  height: 720,
  has_screen: false,
  video_url: 'https://files.test/video.mp4',
  poster_url: null,
  speakers: [],
};

const transcript = {
  id: 't1',
  session_id: 's1',
  recording_id: 'rec1',
  community_id: 'c1',
  room_id: 'r1',
  room_name: 'general',
  post_id: null,
  topic: 'Pruning roses',
  status: 'ready',
  failure: null,
  language: null,
  duration_ms: 90_000,
  started_at: at,
  ready_at: at,
  speakers: [{ id: 'sp1', index: 0, user_id: 'u1', label: null }],
  segments: [
    {
      id: 'seg1',
      speaker_id: 'sp1',
      start_ms: 65_000,
      end_ms: 70_000,
      text: 'Cut above the bud',
      edited: false,
      editable: true,
    },
  ],
  silences: [],
  people: [
    { id: 'u1', username: me.username, display_name: null, avatar_id: null, avatar_url: null },
  ],
  recording,
};

const signedIn = async () => {
  routes['POST /api/auth/sessions'] = { status: 200, body: session };
  routes['GET /api/communities'] = { status: 200, body: [community] };

  const { gateway: g, store } = gateway();

  await g.session.verifyCode('ada@example.com', '123456');

  return { g, store };
};

describe('transcripts', () => {
  it('fails when the server has none', async () => {
    routes['GET /api/voice-sessions/s1/transcript'] = {
      status: 404,
      body: { code: 'not_found', message: 'Not found' },
    };

    const { g, store } = await signedIn();

    expect((await g.load.transcript('s1')).ok).toBe(false);
    expect(store.get().transcripts['s1']).toBeUndefined();
  });

  it('keeps the transcript under its session with each line by its speaker', async () => {
    routes['GET /api/voice-sessions/s1/transcript'] = { status: 200, body: transcript };

    const { g, store } = await signedIn();

    expect((await g.load.transcript('s1')).ok).toBe(true);

    expect(store.get().transcripts['s1']).toEqual(
      expect.objectContaining({
        c: 'gardeners',
        title: 'Pruning roses',
        recording: 'rec1',
        speakers: ['u1'],
        lines: [{ id: 'seg1', who: 'u1', t: '1:05', text: 'Cut above the bud', editable: true }],
      }),
    );

    expect(store.get().recordings['rec1']?.url).toBe('https://files.test/video.mp4');
  });

  it('fixes a line', async () => {
    routes['GET /api/voice-sessions/s1/transcript'] = { status: 200, body: transcript };
    routes['PUT /api/transcript-segments/seg1'] = {
      status: 200,
      body: { ...transcript.segments[0], text: 'Cut just above the bud', edited: true },
    };

    const { g, store } = await signedIn();

    await g.load.transcript('s1');

    expect((await g.voice.editTranscriptLine('s1', 'seg1', 'Cut just above the bud')).ok).toBe(
      true,
    );

    expect(sent).toContainEqual(
      expect.objectContaining({ method: 'PUT', body: { text: 'Cut just above the bud' } }),
    );
    expect(store.get().transcripts['s1']?.lines[0]?.text).toBe('Cut just above the bud');
  });
});
