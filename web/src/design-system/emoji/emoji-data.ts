import type { EmojiMartData } from '@emoji-mart/data';
import type PickerComponent from '@emoji-mart/react';
import { useSyncExternalStore } from 'react';

type Glyphs = Readonly<Record<string, string>>;

const COMMON: Glyphs = {
  '+1': '👍',
  '-1': '👎',
  heart: '❤️',
  joy: '😂',
  tada: '🎉',
  fire: '🔥',
  eyes: '👀',
  pray: '🙏',
  rocket: '🚀',
  '100': '💯',
  clap: '👏',
  smile: '😄',
  thinking_face: '🤔',
  raised_hands: '🙌',
  white_check_mark: '✅',
  muscle: '💪',
  sparkles: '✨',
  wave: '👋',
  laughing: '😆',
  heart_eyes: '😍',
  cry: '😢',
  sob: '😭',
  ok_hand: '👌',
  star: '⭐',
  bulb: '💡',
  books: '📚',
  runner: '🏃',
  coffee: '☕',
};

let glyphs: Glyphs | null = null;
let glyphsLoading: Promise<Glyphs> | null = null;

export type EmojiPickerKit = { data: EmojiMartData; Picker: typeof PickerComponent };

let pickerKit: Promise<EmojiPickerKit> | null = null;
let loadedKit: EmojiPickerKit | null = null;
const listeners = new Set<() => void>();

const isShortcode = (value: string) =>
  value.length > 2 &&
  value.startsWith(':') &&
  value.endsWith(':') &&
  !value.slice(1, -1).includes(' ');

function loadGlyphs(): Promise<Glyphs> {
  glyphsLoading ??= import('./glyphs.json').then((m) => {
    glyphs = m.default as Glyphs;
    listeners.forEach((l) => l());
    return glyphs;
  });

  return glyphsLoading;
}

export function loadEmojiPicker(): Promise<EmojiPickerKit> {
  pickerKit ??= Promise.all([
    import('@emoji-mart/data'),
    import('emoji-mart'),
    import('@emoji-mart/react'),
  ]).then(([dataModule, mart, react]) => {
    const data = dataModule.default as EmojiMartData;

    mart.init({ data, set: 'native' });
    loadedKit = { data, Picker: react.default };

    return loadedKit;
  });

  return pickerKit;
}

export const loadedEmojiPicker = (): EmojiPickerKit | null => loadedKit;

export function preloadEmojiPicker() {
  void loadEmojiPicker();
}

function subscribe(listener: () => void) {
  listeners.add(listener);

  return () => {
    listeners.delete(listener);
  };
}

export function useEmojiGlyph(value: string): string | null {
  const id = isShortcode(value) ? value.slice(1, -1) : null;
  const known = id ? (COMMON[id] ?? null) : null;

  const loadedGlyph = useSyncExternalStore(
    subscribe,
    () => (id && !known ? (glyphs?.[id] ?? null) : null),
    () => null,
  );

  if (id && !known && !glyphs) void loadGlyphs();

  return known ?? loadedGlyph;
}

export const emojiKey = (id: string) => `:${id}:`;

export const isEmojiKey = isShortcode;
