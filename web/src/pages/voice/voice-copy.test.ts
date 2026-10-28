import { describe, expect, it } from 'vitest';
import { keptForLater, startNotice } from './voice-copy';

describe('keptForLater/3', () => {
  it('promises nothing where nothing is kept', () => {
    expect(keptForLater(false, false, 'to the post')).toBe('');
  });

  it('names only what the instance keeps', () => {
    expect(keptForLater(true, false, 'to the post')).toBe('The transcript is saved to the post.');
    expect(keptForLater(false, true, 'to the post')).toBe('Any recording is saved to the post.');
    expect(keptForLater(true, true, 'to the post')).toBe(
      'The transcript and any recording are saved to the post.',
    );
  });
});

describe('startNotice/2', () => {
  it('tells someone outside the community that members hear about it', () => {
    expect(startNotice(false, false)).toBe(
      'When it starts, members of this community get a quiet notification.',
    );
  });

  it('tells a member they will hear about it too', () => {
    expect(startNotice(false, true)).toBe(
      'When it starts, you and everyone else here get a quiet notification.',
    );
  });

  it('tells someone who can start it who hears about it', () => {
    expect(startNotice(true, true)).toBe(
      'Start it and everyone else in this community gets a quiet notification.',
    );
  });
});
