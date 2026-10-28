import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { feelCue, setHapticsEnabled } from './haptics';

const trigger = vi.hoisted(() => vi.fn(() => Promise.resolve()));

vi.mock('web-haptics', () => ({
  WebHaptics: class {
    trigger = trigger;
  },
}));

function onPhone(phone: boolean) {
  vi.stubGlobal('matchMedia', (query: string) => ({ matches: phone, media: query }));
}

describe('feelCue/1', () => {
  beforeEach(() => setHapticsEnabled(true));

  afterEach(() => {
    vi.unstubAllGlobals();
    trigger.mockClear();
  });

  it('stays still when haptics are off', () => {
    onPhone(true);
    setHapticsEnabled(false);

    feelCue('join');

    expect(trigger).not.toHaveBeenCalled();
  });

  it('stays still on a computer', () => {
    onPhone(false);

    feelCue('join');

    expect(trigger).not.toHaveBeenCalled();
  });

  it('stays still for cues that only make a sound', () => {
    onPhone(true);

    feelCue('toast');

    expect(trigger).not.toHaveBeenCalled();
  });

  it('buzzes on a phone when you join a room', () => {
    onPhone(true);

    feelCue('join');

    expect(trigger).toHaveBeenCalledWith('success');
  });
});
