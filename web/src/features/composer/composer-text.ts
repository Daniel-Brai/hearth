import type { AppState } from '@/domain/app-state';
import {
  allTags,
  canSeeName,
  displayName,
  findPerson,
  handle,
  person,
  sharesCommunity,
} from '@/domain/selectors';
import type { IconName } from '@/design-system';
import type { Token, Tokens } from 'marked';
import { lexMarkdown, type MentionToken } from '@/features/markdown/markdown';

export type SuggestKind = '@' | '#' | '/' | 'sound';

export type Suggestion = {
  readonly label: string;
  readonly sub: string | null;
  readonly hint: string | null;
  readonly insert: string;
  readonly icon: IconName;
  readonly person?: string | undefined;
  readonly disabled?: boolean | undefined;
  readonly reason?: string | undefined;
  readonly reopen?: boolean | undefined;
};

type Command = {
  cmd: string;
  args: string;
  desc: string;
  ok: boolean;
  reason?: string | undefined;
  icon: string;
};

export type SuggestOptions = {
  readonly community: string | null;
  readonly commands?: readonly Command[] | undefined;
  readonly sounds?: readonly string[] | undefined;
  readonly chat: boolean;
};

const esc = (s: string) =>
  s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

const isWordChar = (ch: string) => /\w/.test(ch);

function wordAtCaret(
  text: string,
  caret: number,
): { sigil: string; word: string; start: number } | null {
  let i = caret;

  while (i > 0 && (isWordChar(text[i - 1]!) || text[i - 1] === '.' || text[i - 1] === '-')) i--;

  const sigil = text[i - 1];

  if (sigil !== '@' && sigil !== '#' && sigil !== '/') return null;

  const before = text[i - 2];

  if (before !== undefined && before !== ' ' && before !== '\n' && before !== '(') return null;

  return { sigil, word: text.slice(i, caret), start: i - 1 };
}

export function mentionAt(text: string, caret: number): string | null {
  const w = wordAtCaret(text, caret);
  return w?.sigil === '@' ? w.word : null;
}

function looselyIn(name: string, typed: string): boolean {
  let at = 0;
  for (const ch of name.toLowerCase()) if (ch === typed[at]) at++;
  return at === typed.length;
}

const inCommunity = (state: AppState, cid: string | null, id: string) =>
  cid !== null && state.roles.some((r) => r.c === cid && r.members.includes(id));

export function suggest(state: AppState, text: string, caret: number, opts: SuggestOptions) {
  const before = text.slice(0, caret);

  if (opts.chat && opts.sounds && before.startsWith('/play ') && !before.slice(6).includes(' ')) {
    const typed = before.slice(6).toLowerCase();
    const play = opts.commands?.find((c) => c.cmd === 'play');

    const items: Suggestion[] = opts.sounds
      .filter((s) => s.startsWith(typed))
      .map((s) => ({
        label: s,
        sub: null,
        hint: null,
        insert: s + ' ',
        icon: 'music',
        disabled: play ? !play.ok : false,
        reason: play?.reason,
      }));

    return items.length ? { kind: 'sound' as const, items, start: 6, end: caret } : null;
  }

  const w = wordAtCaret(text, caret);

  if (!w) return null;

  if (w.sigil === '/') {
    if (!opts.chat || w.start !== 0) return null;

    const typed = w.word.toLowerCase();

    const items: Suggestion[] = (opts.commands ?? [])
      .filter((c) => c.cmd.startsWith(typed))
      .map((c) => ({
        label: '/' + c.cmd,
        sub: c.args,
        hint: c.desc,
        insert: '/' + c.cmd + ' ',
        icon: c.icon as IconName,
        disabled: !c.ok,
        reason: c.reason,
        reopen: c.cmd === 'play',
      }));

    return items.length ? { kind: '/' as const, items, start: 0, end: caret } : null;
  }

  if (w.sigil === '@') {
    const typed = w.word.toLowerCase();
    const items: Suggestion[] = Object.keys(state.people)
      .filter((id) => sharesCommunity(state, id) || inCommunity(state, opts.community, id))
      .filter((id) => {
        const p = state.people[id]!;
        return (
          !typed ||
          looselyIn(p.username, typed) ||
          (canSeeName(state, id) && looselyIn(p.name, typed))
        );
      })
      .sort(
        (a, b) =>
          Number(inCommunity(state, opts.community, b)) -
          Number(inCommunity(state, opts.community, a)),
      )
      .slice(0, 6)
      .map((id) => ({
        label: displayName(state, id),
        sub: handle(state, id),
        hint: id === state.me ? 'You' : null,
        insert: '@' + person(state, id).username + ' ',
        icon: 'user',
        person: id,
      }));
    return items.length ? { kind: '@' as const, items, start: w.start, end: caret } : null;
  }

  const typed = w.word.toLowerCase();
  const c = opts.community ? state.communities[opts.community] : undefined;

  const rooms: Suggestion[] = (c?.rooms ?? [])
    .filter((r) => r.name.includes(typed))
    .map((r) => ({
      label: '#' + r.name,
      sub: 'Room in ' + c!.name,
      hint: null,
      insert: '#' + r.name + ' ',
      icon: 'hash',
    }));

  const tags: Suggestion[] = allTags(state, opts.community)
    .filter((t) => t.includes(typed))
    .slice(0, 6)
    .map((t) => ({
      label: '#' + t,
      sub: 'Tag',
      hint: state.posts.filter((p) => p.tags.includes(t)).length + ' posts',
      insert: '#' + t + ' ',
      icon: 'tag',
    }));

  const items = rooms.concat(tags);

  if (typed && !items.some((i) => i.label === '#' + typed))
    items.push({
      label: '#' + typed,
      sub: 'New tag',
      hint: null,
      insert: '#' + typed + ' ',
      icon: 'plus',
    });

  return items.length ? { kind: '#' as const, items, start: w.start, end: caret } : null;
}

const tokenClass = (valid: boolean, typing: boolean) => {
  if (valid) return 'tok tok--cmd';
  if (typing) return 'tok';
  return 'tok tok--bad';
};

type HighlightOptions = Pick<SuggestOptions, 'commands' | 'sounds' | 'chat'>;

export function highlight(state: AppState, text: string, opts: HighlightOptions): string {
  let rest = text;
  let out = '';

  if (opts.chat && rest.startsWith('/')) {
    const space = [...rest].findIndex((ch) => ch.trim() === '');
    const name = space < 0 ? rest.slice(1) : rest.slice(1, space);
    const cmd = opts.commands?.find((c) => c.cmd === name.toLowerCase());
    const typing = !cmd && (opts.commands ?? []).some((c) => c.cmd.startsWith(name.toLowerCase()));

    out += `<span class="${tokenClass(!!cmd?.ok, typing)}">/${esc(name)}</span>`;
    rest = space < 0 ? '' : rest.slice(space);

    if (cmd?.cmd === 'play' && rest.trim()) {
      const lead = rest.length - rest.trimStart().length;
      const arg = rest.trimStart().split(' ')[0]!;
      const okSound = opts.sounds?.includes(arg.toLowerCase());

      const partial =
        !okSound &&
        !rest.endsWith(' ') &&
        opts.sounds?.some((s) => s.startsWith(arg.toLowerCase()));

      out +=
        esc(rest.slice(0, lead)) +
        `<span class="${tokenClass(!!okSound, !!partial)}">${esc(arg)}</span>`;

      rest = rest.slice(lead + arg.length);
    }
  }

  const { tokens } = lexMarkdown(rest);
  const spans: { start: number; end: number; cls: string }[] = [];
  let cursor = 0;

  const walk = (list: readonly Token[]) => {
    for (const t of list) {
      const at = rest.indexOf(t.raw, cursor);
      if (at < 0) continue;

      if (t.type === 'mention') {
        const handleText = (t as MentionToken).handle;
        spans.push({
          start: at,
          end: at + t.raw.length,
          cls: findPerson(state, handleText) ? 'tok tok--mention' : 'tok',
        });
        cursor = at + t.raw.length;
      } else if (t.type === 'ref') {
        spans.push({ start: at, end: at + t.raw.length, cls: 'tok tok--ref' });
        cursor = at + t.raw.length;
      } else if (t.type === 'codespan' || t.type === 'code') {
        spans.push({ start: at, end: at + t.raw.length, cls: 'tok tok--code' });
        cursor = at + t.raw.length;
      } else if (t.type === 'link' && (t as Tokens.Link).href.startsWith('http')) {
        spans.push({ start: at, end: at + t.raw.length, cls: 'tok tok--link' });
        cursor = at + t.raw.length;
      } else if ('tokens' in t && t.tokens) {
        walk(t.tokens);
      } else if ('items' in t) {
        (t as Tokens.List).items.forEach((i) => walk(i.tokens));
      }
    }
  };

  walk(tokens);

  let last = 0;

  for (const s of spans) {
    out +=
      esc(rest.slice(last, s.start)) +
      `<span class="${s.cls}">${esc(rest.slice(s.start, s.end))}</span>`;
    last = s.end;
  }

  out += esc(rest.slice(last));

  return out + (text.endsWith('\n') ? '​' : '');
}
