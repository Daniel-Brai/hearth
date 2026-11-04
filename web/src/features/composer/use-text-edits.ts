import type { RefObject } from 'react';

import type { Attachment } from '@/domain/types';
import {
  alignImageIn,
  attachmentHref,
  carouselIn,
  imageAlignIn,
  inCarouselIn,
  moveImageIn,
  removeImageFrom,
  type ImageAlign,
} from '@/features/markdown/image-align';

import { paragraphGap } from './composer-files';

type Where = 'cursor' | 'end';

/**
 * Focuses at once so a phone keeps its keyboard up during the tap, then selects once the new
 * text has rendered
 */
function selectAfterRender(el: HTMLTextAreaElement, start: number, end: number) {
  el.focus();
  requestAnimationFrame(() => el.setSelectionRange(start, end));
}

export function useTextEdits(
  textarea: RefObject<HTMLTextAreaElement | null>,
  value: string,
  onChange: (next: string) => void,
) {
  const wrap = (before: string, after: string, fallback: string) => {
    const el = textarea.current;

    if (!el) return;

    const s = el.selectionStart;
    const end = el.selectionEnd;
    const selected = value.slice(s, end) || fallback;

    onChange(value.slice(0, s) + before + selected + after + value.slice(end));

    selectAfterRender(el, s + before.length, s + before.length + selected.length);
  };

  /** Prefixes every line the selection touches, or the cursor's line, for quotes and lists */
  const prefixLines = (prefix: (line: number) => string, fallback: string) => {
    const el = textarea.current;

    if (!el) return;

    const start = value.lastIndexOf('\n', el.selectionStart - 1) + 1;
    const lineEnd = value.indexOf('\n', el.selectionEnd);
    const end = lineEnd === -1 ? value.length : lineEnd;
    const lines = (value.slice(start, end) || fallback).split('\n');
    const text = lines.map((line, i) => prefix(i) + line).join('\n');

    onChange(value.slice(0, start) + text + value.slice(end));

    selectAfterRender(el, start, start + text.length);
  };

  /** Wraps the selection in lines of its own, apart from the text around it */
  const block = (before: string, after: string, fallback: string) => {
    const el = textarea.current;

    if (!el) return;

    const s = el.selectionStart;
    const end = el.selectionEnd;
    const head = value.slice(0, s);
    const tail = value.slice(end);
    const selected = value.slice(s, end) || fallback;
    const opening = paragraphGap(head, 'end') + before;

    onChange(head + opening + selected + after + paragraphGap(tail, 'start') + tail);

    selectAfterRender(el, s + opening.length, s + opening.length + selected.length);
  };

  const placed = (f: Attachment) => imageAlignIn(value, f.id) !== null;

  const placeInText = (f: Attachment, where: Where) => {
    const snippet = `![${f.name}](${attachmentHref(f.id)})`;
    const el = textarea.current;
    const at = where === 'cursor' && el ? el.selectionStart : value.length;
    const before = value.slice(0, at);
    const after = value.slice(at);

    onChange(before + paragraphGap(before, 'end') + snippet + paragraphGap(after, 'start') + after);
  };

  const unplace = (f: Attachment) => onChange(removeImageFrom(value, f.id));

  const moveImage = (f: Attachment, where: Where) => {
    const el = textarea.current;
    onChange(moveImageIn(value, f.id, where === 'cursor' && el ? el.selectionStart : 'end'));
  };

  const alignImage = (f: Attachment, align: ImageAlign) => {
    if (placed(f)) {
      onChange(alignImageIn(value, f.id, align));
      return;
    }

    const snippet = `![${f.name}](${attachmentHref(f.id, align)})`;
    onChange(value + paragraphGap(value, 'end') + snippet);
  };

  const inCarousel = (f: Attachment) => inCarouselIn(value, f.id);

  const carousel = (images: readonly Attachment[]) => {
    const el = textarea.current;
    onChange(carouselIn(value, images, el ? el.selectionStart : 'end'));
  };

  return {
    wrap,
    prefixLines,
    block,
    placed,
    placeInText,
    unplace,
    moveImage,
    alignImage,
    inCarousel,
    carousel,
  };
}

export type TextEdits = ReturnType<typeof useTextEdits>;
