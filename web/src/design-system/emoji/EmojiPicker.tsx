import { useEffect, useState, type KeyboardEvent } from 'react';
import { useMenu } from '../components/menu-context';
import { emojiKey, loadedEmojiPicker, loadEmojiPicker } from './emoji-data';
import { pickerThemeStyle } from './picker-theme';

export type EmojiPickerProps = {
  readonly onPick: (key: string) => void;
  readonly autoFocus?: boolean | undefined;
};

type PickedEmoji = { id: string };

const isDark = () => {
  const forced = document.documentElement.dataset.theme;

  if (forced === 'dark') return true;
  if (forced === 'light') return false;

  return window.matchMedia('(prefers-color-scheme: dark)').matches;
};

export function EmojiPicker({ onPick, autoFocus = true }: EmojiPickerProps) {
  const menu = useMenu();
  const [kit, setKit] = useState(loadedEmojiPicker);
  const [themeStyle] = useState(pickerThemeStyle);

  useEffect(() => {
    if (kit) return;

    let cancelled = false;

    void loadEmojiPicker().then((loaded) => {
      if (!cancelled) setKit(loaded);
    });

    return () => {
      cancelled = true;
    };
  }, [kit]);

  if (!kit) return <div className="emoji-picker emoji-picker--loading" aria-busy="true" />;

  const { Picker, data } = kit;

  // The search box keeps Escape inside the shadow DOM so it is caught on the way in
  const onEscape = (e: KeyboardEvent<HTMLDivElement>) => {
    if (e.key !== 'Escape' || !menu) return;

    const target = e.nativeEvent.composedPath()[0];

    if (target instanceof HTMLInputElement && target.value) return;

    e.stopPropagation();
    menu.close();
  };

  return (
    <div className="emoji-picker" style={themeStyle} onKeyDownCapture={onEscape}>
      <Picker
        data={data}
        set="native"
        theme={isDark() ? 'dark' : 'light'}
        autoFocus={autoFocus}
        previewPosition="none"
        skinTonePosition="search"
        navPosition="bottom"
        perLine={8}
        emojiSize={22}
        emojiButtonSize={32}
        maxFrequentRows={2}
        onEmojiSelect={(emoji: PickedEmoji) => onPick(emojiKey(emoji.id))}
      />
    </div>
  );
}
