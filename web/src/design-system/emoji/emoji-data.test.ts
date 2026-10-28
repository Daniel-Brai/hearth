import { describe, expect, it } from 'vitest';
import { loadedEmojiPicker, loadEmojiPicker } from './emoji-data';

describe('loadEmojiPicker', () => {
  it('loads the picker once and keeps it for the next open', async () => {
    expect(loadedEmojiPicker()).toBeNull();

    const first = loadEmojiPicker();

    expect(loadEmojiPicker()).toBe(first);

    const kit = await first;

    expect(kit.Picker).toBeTypeOf('function');
    expect(Object.keys(kit.data.emojis).length).toBeGreaterThan(1000);
    expect(loadedEmojiPicker()).toBe(kit);
  });
});
