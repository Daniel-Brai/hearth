import { afterEach, describe, expect, it, vi } from 'vitest';
import { floatReaction, getRoomSession, useVoiceSession } from './voice-session';

afterEach(() => {
  useVoiceSession.getState().drop('c/r');
  vi.useRealTimers();
});

describe('floatReaction/3', () => {
  it('never lets a burst cover the room', () => {
    for (let n = 0; n < 20; n++) floatReaction('c/r', 'ada', ':tada:');

    expect(getRoomSession('c/r').floats).toHaveLength(8);
  });

  it('floats away after a moment', () => {
    vi.useFakeTimers();
    floatReaction('c/r', 'ada', ':heart:');

    vi.advanceTimersByTime(2000);

    expect(getRoomSession('c/r').floats).toEqual([]);
  });
});

describe('self-talking', () => {
  it('keeps your own talking apart from what the server reports', () => {
    const { dispatch } = useVoiceSession.getState();

    dispatch('c/r', { type: 'self-talking', talking: true });

    dispatch('c/r', {
      type: 'synced',
      snapshot: {
        speakers: [],
        listeners: [],
        hands: [],
        muted: [],
        locked: [],
        speaking: [],
        share: null,
        recording: { on: false },
        handUp: false,
      },
    });

    expect(getRoomSession('c/r').selfTalking).toBe(true);
  });
});
