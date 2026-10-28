import { useRef, useState, type KeyboardEvent, type RefObject } from 'react';
import { useGateway } from '@/app/gateway-context';
import { getStore } from '@/data/store';
import type { AppState } from '@/domain/app-state';
import { useUi } from '@/runtime/ui-store';
import {
  mentionAt,
  suggest,
  type SuggestKind,
  type Suggestion,
  type SuggestOptions,
} from './composer-text';

const SEARCH_DELAY_MS = 150;

type Open = {
  kind: SuggestKind;
  items: Suggestion[];
  start: number;
  end: number;
};

function placeCaret(el: HTMLTextAreaElement, text: string, pos: number) {
  el.value = text;
  el.focus();
  el.setSelectionRange(pos, pos);
}

export function useSuggestions({
  state,
  value,
  onChange,
  textarea,
  options,
}: {
  readonly state: AppState;
  readonly value: string;
  readonly onChange: (next: string) => void;
  readonly textarea: RefObject<HTMLTextAreaElement | null>;
  readonly options: SuggestOptions;
}) {
  const flash = useUi((s) => s.flash);
  const [suggestions, setSuggestions] = useState<Open | null>(null);
  const [index, setIndex] = useState(0);

  const gateway = useGateway();
  const searching = useRef<number | null>(null);

  const show = (found: Open | null) => {
    setSuggestions(found);
    setIndex(
      found
        ? Math.max(
            0,
            found.items.findIndex((i) => !i.disabled),
          )
        : 0,
    );
  };

  const search = (el: HTMLTextAreaElement) => {
    const word = mentionAt(el.value, el.selectionStart);
    const community = options.community;

    if (word === null || community === null) return;

    if (searching.current !== null) window.clearTimeout(searching.current);

    const text = el.value;
    const caret = el.selectionStart;

    searching.current = window.setTimeout(() => {
      void gateway.load.mentionable(community, word).then(() => {
        if (el.value !== text || el.selectionStart !== caret) return;

        show(suggest(getStore().get(), text, caret, options));
      });
    }, SEARCH_DELAY_MS);
  };

  const update = (el: HTMLTextAreaElement) => {
    show(suggest(state, el.value, el.selectionStart, options));
    search(el);
  };

  const close = () => setSuggestions(null);

  const pick = (s: Suggestion) => {
    if (!suggestions) return;

    if (s.disabled) {
      flash(s.reason ?? 'Not available here');
      return;
    }

    const next = value.slice(0, suggestions.start) + s.insert + value.slice(suggestions.end);
    const pos = suggestions.start + s.insert.length;

    onChange(next);
    close();

    const el = textarea.current;

    if (!el) return;
    placeCaret(el, next, pos);
    if (s.reopen) update(el);
  };

  const handleKey = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (!suggestions?.items.length) return false;

    const count = suggestions.items.length;

    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setIndex((i) => (i + 1) % count);
      return true;
    }

    if (e.key === 'ArrowUp') {
      e.preventDefault();
      setIndex((i) => (i - 1 + count) % count);
      return true;
    }

    if (e.key === 'Enter' || e.key === 'Tab') {
      e.preventDefault();

      const s = suggestions.items[index];

      if (s) pick(s);

      return true;
    }

    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      close();

      return true;
    }

    return false;
  };

  return { suggestions, index, setIndex, update, close, pick, handleKey };
}
