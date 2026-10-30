import DOMPurify, { type WindowLike } from 'dompurify';
import { Marked, Parser, type Tokens, type TokensList } from 'marked';
import type { AppState } from '@/domain/app-state';
import { canSeeName, findPerson, findRoom, person } from '@/domain/selectors';
import { shortLink } from '@/domain/links';
import { attachmentDownload, attachmentSrc, type Attachment } from '@/domain/types';
import { blurUrl } from '@/design-system/components/blur';
import { ICONS } from '@/design-system/icons/icons';
import { routes } from '@/runtime/routes';
import { splitImageHref, type ImageAlign } from './image-align';

/** The server render has no DOM so it passes one in with setMarkdownWindow */
let purify = DOMPurify;
let parseHtml = (html: string) => new DOMParser().parseFromString(html, 'text/html');

export function setMarkdownWindow(window: WindowLike & { DOMParser: typeof DOMParser }) {
  purify = DOMPurify(window);
  parseHtml = (html) => new window.DOMParser().parseFromString(html, 'text/html');
}

const esc = (s: string) =>
  s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const icon = (name: keyof typeof ICONS) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name]}</svg>`;

export const CODE_COLLAPSE_AFTER = 20;

export type MentionToken = Tokens.Generic & { type: 'mention'; handle: string };
type RefToken = Tokens.Generic & { type: 'ref'; name: string };

export type RenderContext = {
  readonly state: AppState;
  readonly community: string | null;
  readonly files?: readonly Attachment[];
  /** True when the message's @all came from someone allowed to ping the whole room */
  readonly everyone?: boolean | undefined;
};

/** Extensions are registered once so the people and rooms for @mentions are set around each render */
let ctx: RenderContext | null = null;

let dropImages = false;

function mentionHtml(handleText: string, raw: string) {
  if (!ctx) return esc(raw);

  if (handleText.toLowerCase() === 'all') {
    return ctx.everyone
      ? '<span class="mention mention--me" title="Everyone who can see this room">@all</span>'
      : esc(raw);
  }

  const { state } = ctx;
  const id = findPerson(state, handleText);

  if (!id) return esc(raw);

  const p = person(state, id);
  const label = canSeeName(state, id) ? p.name : p.username;
  const me = id === state.me ? ' mention--me' : '';

  return `<a class="mention${me}" href="${routes.profile(p.username)}" title="@${esc(p.username)}">@${esc(label)}</a>`;
}

function refHtml(name: string, raw: string) {
  if (!ctx) return esc(raw);

  const { state, community } = ctx;

  if (!community) return esc(raw);

  const room = findRoom(state, name, community);

  if (room)
    return `<a class="ref ref--room" href="${routes.chat(community, room.id)}">#${esc(room.name)}</a>`;

  return `<a class="ref ref--tag" href="${routes.tag(community, name.toLowerCase())}">#${esc(name)}</a>`;
}

const SAFE_PROTOCOLS = new Set(['http:', 'https:', 'mailto:']);

const isSafeHref = (href: string) => {
  if (href.startsWith('/') || href.startsWith('#')) return true;
  try {
    return SAFE_PROTOCOLS.has(new URL(href).protocol);
  } catch {
    return false;
  }
};

const isWeb = (href: string) => href.startsWith('http://') || href.startsWith('https://');

type ResolvedImage = {
  readonly src: string;
  readonly alt: string;
  readonly align: ImageAlign;
  readonly width?: number | undefined;
  readonly height?: number | undefined;
  readonly blurhash?: string | undefined;
};

const attachmentFor = (href: string) =>
  ctx?.files?.find((x) => x.id === href.slice('attachment:'.length));

function resolveImage(rawHref: string, text: string): ResolvedImage | null {
  const { src, align } = splitImageHref(rawHref);

  if (src.startsWith('https://')) return { src, alt: text, align };
  if (!src.startsWith('attachment:')) return null;

  const f = attachmentFor(src);

  if (f?.kind !== 'image') return null;

  return {
    src: attachmentSrc(f),
    alt: text || f.name,
    align,
    width: f.width,
    height: f.height,
    blurhash: f.blurhash,
  };
}

const sizeAttrs = ({ width, height }: ResolvedImage) =>
  width && height ? ` width="${width}" height="${height}"` : '';

const blurOf = (image: ResolvedImage) =>
  image.blurhash ? blurUrl(image.blurhash, image.width, image.height) : null;

const blurAttrs = (image: ResolvedImage) => {
  const blur = blurOf(image);
  return blur ? ` data-blur style="--blur: url(${blur})"` : '';
};

function imageHtml(image: ResolvedImage) {
  const blur = blurOf(image);

  const styles = [
    image.width && image.height ? `--ratio: ${(image.width / image.height).toFixed(4)}` : null,
    blur ? `--blur: url(${blur})` : null,
  ].filter(Boolean);

  const style = styles.length ? ` style="${styles.join('; ')}"` : '';

  return `<img class="md-image md-image--${image.align}" src="${esc(image.src)}" alt="${esc(image.alt)}"${sizeAttrs(image)}${style}${blur ? ' data-blur' : ''} loading="lazy" decoding="async" data-fade="html">`;
}

/** Images on one line each with no blank line between show as one carousel, placed by the first */
function carouselHtml(images: readonly ResolvedImage[]) {
  const first = images[0]!;
  const ratio = first.width && first.height ? `${first.width} / ${first.height}` : '4 / 3';

  const slides = images.map(
    (image, i) =>
      `<div class="carousel__slide" role="group" aria-roledescription="slide" aria-label="${i + 1} of ${images.length}"${i === 0 ? '' : ' inert'}>` +
      `<img class="carousel__backdrop" src="${esc(image.src)}" alt="" loading="lazy" decoding="async">` +
      `<button type="button" class="carousel__open" data-open-image aria-label="Open ${esc(image.alt)}">` +
      `<img class="carousel__image" src="${esc(image.src)}" alt="${esc(image.alt)}"${sizeAttrs(image)}${blurAttrs(image)} loading="lazy" decoding="async" data-fade="html"></button></div>`,
  );

  const step = (by: number, label: string, disabled: boolean) =>
    `<button type="button" class="btn btn--small btn--circle carousel__${by < 0 ? 'prev' : 'next'}" data-carousel-step="${by}" aria-label="${label}"${disabled ? ' disabled' : ''}>${icon('chevron')}</button>`;

  const dots = images.map((_, i) => (i === 0 ? '<i class="is-current"></i>' : '<i></i>'));

  return (
    `<section class="carousel md-carousel md-carousel--${first.align}" data-carousel aria-roledescription="carousel" aria-label="${images.length} images" tabindex="0" style="--carousel-ratio: ${ratio}">` +
    `<div class="carousel__track">${slides.join('')}</div>` +
    step(-1, 'Previous image', true) +
    step(1, 'Next image', false) +
    `<span class="carousel__count" aria-live="polite">1 / ${images.length}</span>` +
    `<span class="carousel__dots" aria-hidden="true">${dots.join('')}</span></section>`
  );
}

const md = new Marked({
  gfm: true,
  breaks: true,
  renderer: {
    link({ href, title, text, raw }: Tokens.Link) {
      const safe = isSafeHref(href) ? href : '#';
      const external = isWeb(safe);
      // A pasted address is shortened to read, while the link still goes to all of it
      const bare = external && (raw === href || raw === `<${href}>`);
      const label = bare ? esc(shortLink(href)) : text;
      const tip = title ?? (bare && label !== esc(href) ? href : null);
      const t = tip ? ` title="${esc(tip)}"` : '';
      const rel = external ? ' target="_blank" rel="noopener nofollow ugc"' : '';

      return `<a class="md-link" href="${esc(safe)}"${rel}${t}>${label}</a>`;
    },
    image({ href: rawHref, text }: Tokens.Image) {
      if (dropImages) return '';

      const image = resolveImage(rawHref, text);

      if (image) return imageHtml(image);

      const { src: href } = splitImageHref(rawHref);

      if (!href.startsWith('attachment:')) return esc(text);

      const f = attachmentFor(href);

      if (!f)
        return `<span class="md-missing">${icon('image')}${esc(text || 'Image')} was removed</span>`;

      return `<a class="md-link" href="${esc(attachmentDownload(f))}" download="${esc(f.name)}">${esc(text || f.name)}</a>`;
    },
    paragraph({ tokens }: Tokens.Paragraph) {
      const parts = tokens.filter((t) => t.type !== 'br' && t.raw.trim() !== '');

      if (dropImages || parts.length < 2 || parts.some((t) => t.type !== 'image')) return false;

      const images = parts.map((t) =>
        resolveImage((t as Tokens.Image).href, (t as Tokens.Image).text),
      );

      return images.every((image) => image !== null) ? carouselHtml(images) : false;
    },
    code({ text, lang }: Tokens.Code) {
      const language = lang?.trim().split(' ')[0] || null;
      const langAttr = language ? ` data-lang="${esc(language)}"` : '';
      const lines = text.split('\n').length;
      const long = lines > CODE_COLLAPSE_AFTER;

      const more = long
        ? `<button type="button" class="code-block__more" data-code-toggle aria-expanded="false">` +
          `<span class="code-block__more-open">Show all ${lines} lines</span>` +
          `<span class="code-block__more-close">Show less</span>${icon('chevron')}</button>`
        : '';

      return (
        `<div class="code-block"${long ? ' data-long' : ''}><div class="code-block__head"><span>${esc(language ?? 'code')}</span>` +
        `<button type="button" class="code-block__copy" data-copy-code aria-label="Copy code" data-tip="Copy code">${icon('copy')}${icon('check')}</button></div>` +
        `<pre><code data-code${langAttr}>${esc(text)}</code></pre>${more}</div>`
      );
    },
  },
  extensions: [
    {
      name: 'mention',
      level: 'inline',
      start(src: string) {
        const m = /(^|[\s(])@[a-z]/i.exec(src);
        return m ? m.index + m[1]!.length : undefined;
      },
      tokenizer(src: string) {
        const m = /^@([a-z][\w.]*[\w])/i.exec(src) ?? /^@([a-z])/i.exec(src);
        return m ? { type: 'mention', raw: m[0], handle: m[1] } : undefined;
      },
      renderer(t) {
        const token = t as MentionToken;
        return mentionHtml(token.handle, token.raw);
      },
    },
    {
      name: 'ref',
      level: 'inline',
      start(src: string) {
        const m = /(^|[\s(])#[a-z]/i.exec(src);
        return m ? m.index + m[1]!.length : undefined;
      },
      tokenizer(src: string) {
        const m = /^#([a-z][\w-]*[\w]|[a-z])/i.exec(src);
        return m ? { type: 'ref', raw: m[0], name: m[1] } : undefined;
      },
      renderer(t) {
        const token = t as RefToken;
        return refHtml(token.name, token.raw);
      },
    },
  ],
});

const PURIFY_BLOCK = {
  ADD_ATTR: [
    'target',
    'download',
    'data-copy-code',
    'data-code-toggle',
    'data-long',
    'data-tip',
    'data-code',
    'data-lang',
    'data-carousel',
    'data-carousel-step',
  ],
  ALLOWED_URI_REGEXP:
    /^(?:(?:https?|mailto|tel|blob):|data:image\/|[^a-z]|[a-z+.-]+(?:[^a-z+.\-:]|$))/i,
};

const PURIFY_INLINE = {
  ALLOWED_TAGS: ['strong', 'em', 'code', 'a', 'span', 'del', 'b', 'i'],
  ADD_ATTR: ['target'],
};

function withContext<T>(c: RenderContext, fn: () => T): T {
  ctx = c;
  try {
    return fn();
  } finally {
    ctx = null;
  }
}

export function lexMarkdown(text: string): {
  tokens: TokensList;
  mentions: string[];
  refs: string[];
} {
  const mentions: string[] = [];
  const refs: string[] = [];
  const tokens = md.lexer(text);

  md.walkTokens(tokens, (t) => {
    if (t.type === 'mention') mentions.push((t as MentionToken).handle);
    if (t.type === 'ref') refs.push((t as RefToken).name);
  });

  return { tokens, mentions, refs };
}

export function renderMarkdown(text: string | readonly string[], c: RenderContext): string {
  const src = Array.isArray(text) ? text.join('\n\n') : String(text);
  const html = withContext(c, () => md.parse(src, { async: false }));
  return purify.sanitize(html, PURIFY_BLOCK);
}

export function renderInline(
  text: string | readonly string[],
  c: RenderContext,
  noLinks = false,
): string {
  const first = Array.isArray(text) ? text.join('\n\n') : String(text);
  let html: string;

  dropImages = true;

  try {
    html = withContext(c, () => {
      const tokens = md.lexer(first);
      const parts = tokens.map((t) => {
        if (t.type === 'code') return ' … ';
        return 'tokens' in t && t.tokens ? Parser.parseInline(t.tokens, md.defaults) : null;
      });
      return parts.filter((part) => part !== null && part.trim() !== '').join(' ');
    });
  } finally {
    dropImages = false;
  }

  const clean = purify.sanitize(html, PURIFY_INLINE);

  return noLinks ? unlink(clean) : clean;
}

function unlink(html: string): string {
  const doc = parseHtml(`<body>${html}</body>`);
  doc.querySelectorAll('a').forEach((a) => {
    const span = doc.createElement('span');

    span.className = a.className;
    span.append(...a.childNodes);
    a.replaceWith(span);
  });
  return doc.body.innerHTML;
}

export function markdownKey(
  state: AppState,
  refs: { readonly mentions: readonly string[]; readonly refs: readonly string[] },
  community: string | null,
): string {
  const people = refs.mentions.map((h) => {
    const id = findPerson(state, h);

    if (!id) return '-';

    const p = person(state, id);

    return `${id}:${canSeeName(state, id) ? p.name : p.username}:${id === state.me ? 1 : 0}`;
  });
  const rooms = community
    ? refs.refs.map((name) => findRoom(state, name, community)?.name ?? '-')
    : [];

  return people.join('|') + '#' + rooms.join('|');
}
