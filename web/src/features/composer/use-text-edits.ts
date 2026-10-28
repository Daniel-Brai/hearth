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

    requestAnimationFrame(() => {
      el.focus();
      el.setSelectionRange(s + before.length, s + before.length + selected.length);
    });
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

  return { wrap, placed, placeInText, unplace, moveImage, alignImage, inCarousel, carousel };
}

export type TextEdits = ReturnType<typeof useTextEdits>;
