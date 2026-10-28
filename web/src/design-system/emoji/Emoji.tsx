import { isEmojiKey, useEmojiGlyph } from './emoji-data';

export type EmojiProps = {
  readonly value: string;
  readonly className?: string | undefined;
};

export function Emoji({ value, className }: EmojiProps) {
  const glyph = useEmojiGlyph(value);

  if (glyph === null) {
    return (
      <span className={className} aria-busy={isEmojiKey(value) || undefined}>
        {isEmojiKey(value) ? null : value}
      </span>
    );
  }

  return (
    <span className={className} role="img" aria-label={value.slice(1, -1).replaceAll('_', ' ')}>
      {glyph}
    </span>
  );
}
