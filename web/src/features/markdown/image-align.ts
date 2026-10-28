export type ImageAlign = 'left' | 'center' | 'right';

export const IMAGE_ALIGNS: readonly ImageAlign[] = ['left', 'center', 'right'];

const isAlign = (value: string): value is ImageAlign =>
  (IMAGE_ALIGNS as readonly string[]).includes(value);

/** The alignment is a fragment on the address, like attachment:abc#left so stored markdown stays standard */
export function splitImageHref(href: string): { src: string; align: ImageAlign } {
  const hash = href.lastIndexOf('#');
  const fragment = hash >= 0 ? href.slice(hash + 1) : null;

  if (fragment !== null && isAlign(fragment)) return { src: href.slice(0, hash), align: fragment };

  return { src: href, align: 'center' };
}

export const attachmentHref = (id: string, align: ImageAlign = 'center') =>
  `attachment:${id}` + (align === 'center' ? '' : `#${align}`);

function findImage(text: string, id: string): { start: number; end: number; href: string } | null {
  const marker = `(attachment:${id}`;
  const open = text.indexOf(marker);

  if (open < 0) return null;

  const next = text.charAt(open + marker.length);

  if (next !== ')' && next !== '#') return null;

  const close = text.indexOf(')', open);

  if (close < 0) return null;

  const start = text.lastIndexOf('![', open);

  return { start: start >= 0 ? start : open, end: close + 1, href: text.slice(open + 1, close) };
}

const IMAGE = /!\[[^\]]*\]\([^)\s]+\)/g;

/** The paragraph around a position when it holds two or more images and nothing else */
function carouselAround(text: string, at: number): { start: number; end: number } | null {
  const before = text.lastIndexOf('\n\n', at);
  const after = text.indexOf('\n\n', at);
  const start = before < 0 ? 0 : before + 2;
  const end = after < 0 ? text.length : after;
  const block = text.slice(start, end);
  const count = block.match(IMAGE)?.length ?? 0;

  return count > 1 && !block.replace(IMAGE, '').trim() ? { start, end } : null;
}

export function inCarouselIn(text: string, id: string): boolean {
  const found = findImage(text, id);
  return found !== null && carouselAround(text, found.start) !== null;
}

export function imageAlignIn(text: string, id: string): ImageAlign | null {
  const found = findImage(text, id);
  return found ? splitImageHref(found.href).align : null;
}

export function alignImageIn(text: string, id: string, align: ImageAlign): string {
  const found = findImage(text, id);

  if (!found) return text;

  const carousel = carouselAround(text, found.start);

  if (carousel) {
    const block = text
      .slice(carousel.start, carousel.end)
      .replace(
        /\(attachment:([^)#]+)(?:#[a-z]+)?\)/g,
        (_, image: string) => `(${attachmentHref(image, align)})`,
      );

    return text.slice(0, carousel.start) + block + text.slice(carousel.end);
  }

  const open = found.start + text.slice(found.start, found.end).indexOf('(') + 1;

  return text.slice(0, open) + attachmentHref(id, align) + text.slice(found.end - 1);
}

export function removeImageFrom(text: string, id: string): string {
  const found = findImage(text, id);

  if (!found) return text;

  let out = text.slice(0, found.start) + text.slice(found.end);

  while (out.includes('\n\n\n')) out = out.replaceAll('\n\n\n', '\n\n');

  return out;
}

export function moveImageIn(text: string, id: string, at: number | 'end'): string {
  const found = findImage(text, id);

  if (!found) return text;

  const range = carouselAround(text, found.start) ?? found;
  const snippet = text.slice(range.start, range.end);
  const without = text.slice(0, range.start) + text.slice(range.end);

  let index: number;

  if (at === 'end') index = without.length;
  else if (at >= range.end) index = at - snippet.length;
  else index = Math.min(at, range.start);

  const before = without.slice(0, index).trimEnd();
  const after = without.slice(index).trim();
  let out = [before, snippet, after].filter((part) => part !== '').join('\n\n');

  while (out.includes('\n\n\n')) out = out.replaceAll('\n\n\n', '\n\n');

  return out;
}

/** Puts the images together at a position as one carousel, keeping the first one's alignment */
export function carouselIn(
  text: string,
  images: readonly { readonly id: string; readonly name: string }[],
  at: number | 'end',
): string {
  const align = images.map((image) => imageAlignIn(text, image.id)).find(Boolean) ?? 'center';
  let index = at === 'end' ? text.length : at;

  for (const image of images) {
    const found = findImage(text, image.id);
    if (found && found.start < index && index < found.end) index = found.start;
  }

  let out = `${text.slice(0, index)}\u0000${text.slice(index)}`;

  for (const image of images) out = removeImageFrom(out, image.id);

  const [before = '', after = ''] = out.split('\u0000');
  const block = images.map((image) => `![${image.name}](${attachmentHref(image.id, align)})`);

  out = [before.trim(), block.join('\n'), after.trim()].filter((part) => part !== '').join('\n\n');

  while (out.includes('\n\n\n')) out = out.replaceAll('\n\n\n', '\n\n');

  return out;
}
