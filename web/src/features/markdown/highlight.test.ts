import hljs from 'highlight.js/lib/core';
import { describe, expect, it } from 'vitest';

import { CODE_LANGUAGES } from './code-languages';
import { highlightIn } from './highlight';

const highlighted = (lang: string, code: string) => {
  const root = document.createElement('div');
  const el = document.createElement('code');

  el.dataset.code = '';
  el.dataset.lang = lang;
  el.textContent = code;
  root.append(el);

  highlightIn(root);

  return el;
};

describe('highlightIn', () => {
  it.each(CODE_LANGUAGES.map((l) => l.id))('knows %s from the code block menu', (id) => {
    expect(hljs.getLanguage(id)).toBeDefined();
  });

  it.each(['c', 'h'])('colours C fenced as %s', (lang) => {
    const el = highlighted(lang, '#include <stdio.h>\nint main(void) { return 0; }');

    expect(el.querySelector('.hljs-keyword, .hljs-type')).not.toBeNull();
  });

  it.each(['cpp', 'c++', 'cc', 'hpp'])('colours C++ fenced as %s', (lang) => {
    const el = highlighted(lang, 'int main() { return 0; }');

    expect(el.querySelector('.hljs-keyword, .hljs-type')).not.toBeNull();
  });

  it.each(['haskell', 'hs'])('colours Haskell fenced as %s', (lang) => {
    const el = highlighted(lang, 'main :: IO ()\nmain = putStrLn "hi"');

    expect(el.querySelector('.hljs-type, .hljs-string')).not.toBeNull();
  });
});
