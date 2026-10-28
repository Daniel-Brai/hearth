import { Lexer, type Token, type Tokens } from 'marked';

const isWeb = (href: string) => href.startsWith('http://') || href.startsWith('https://');

type Walk = { skipCode: boolean };

function textOf(tokens: readonly Token[], opts: Walk, out: string[]) {
  for (const t of tokens) {
    switch (t.type) {
      case 'code':
        if (!opts.skipCode) out.push('code');
        break;
      case 'codespan':
        if (!opts.skipCode) out.push((t as Tokens.Codespan).text);
        break;
      case 'image':
        break;
      case 'text':
      case 'escape':
        if ('tokens' in t && t.tokens) textOf(t.tokens, opts, out);
        else out.push((t as Tokens.Text).text);
        break;
      case 'space':
      case 'hr':
      case 'br':
        out.push(' ');
        break;
      default:
        if ('tokens' in t && t.tokens) textOf(t.tokens, opts, out);
        else if ('items' in t)
          (t as Tokens.List).items.forEach((item) => textOf(item.tokens, opts, out));
        else if ('rows' in t) {
          const table = t as Tokens.Table;
          table.header.forEach((c) => textOf(c.tokens, opts, out));
          table.rows.forEach((r) => r.forEach((c) => textOf(c.tokens, opts, out)));
        } else if ('text' in t && typeof t.text === 'string') out.push(t.text);
    }
    out.push(' ');
  }
}

const collapse = (parts: string[]) => parts.join('').split(/\s+/).join(' ').trim();

export function plainText(markdown: string | readonly string[]): string {
  const src = Array.isArray(markdown) ? markdown.join('\n\n') : String(markdown);
  const out: string[] = [];

  textOf(Lexer.lex(src), { skipCode: false }, out);

  return collapse(out);
}

export function plainTextWithoutCode(markdown: string): string {
  const out: string[] = [];
  textOf(Lexer.lex(markdown), { skipCode: true }, out);
  return collapse(out);
}

function findLink(tokens: readonly Token[]): string | null {
  for (const t of tokens) {
    if (t.type === 'code' || t.type === 'codespan') continue;
    if (t.type === 'link' && isWeb((t as Tokens.Link).href)) return (t as Tokens.Link).href;

    if ('tokens' in t && t.tokens) {
      const hit = findLink(t.tokens);
      if (hit) return hit;
    }

    if ('items' in t) {
      for (const item of (t as Tokens.List).items) {
        const hit = findLink(item.tokens);
        if (hit) return hit;
      }
    }
  }
  return null;
}

export const firstLink = (markdown: string): string | null =>
  findLink(Lexer.lex(markdown, { gfm: true }));
