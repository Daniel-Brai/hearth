import { render } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { RecordingBanner } from './RecordingBanner';

const show = (canStop: boolean) =>
  render(<RecordingBanner startedAt={Date.now()} canStop={canStop} onStop={() => undefined} />);

describe('RecordingBanner', () => {
  it('only shows how long it has run to someone who cannot stop it', () => {
    show(false);

    expect(document.querySelector('#voice-rec-stop')).toBeNull();
  });

  it('puts a Stop button in the pill for someone who can stop it', () => {
    show(true);

    expect(document.querySelector('#voice-rec-banner #voice-rec-stop')).not.toBeNull();
  });
});
