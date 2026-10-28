import hljs from 'highlight.js/lib/core';
import bash from 'highlight.js/lib/languages/bash';
import css from 'highlight.js/lib/languages/css';
import elixir from 'highlight.js/lib/languages/elixir';
import go from 'highlight.js/lib/languages/go';
import javascript from 'highlight.js/lib/languages/javascript';
import json from 'highlight.js/lib/languages/json';
import python from 'highlight.js/lib/languages/python';
import ruby from 'highlight.js/lib/languages/ruby';
import rust from 'highlight.js/lib/languages/rust';
import sql from 'highlight.js/lib/languages/sql';
import typescript from 'highlight.js/lib/languages/typescript';
import xml from 'highlight.js/lib/languages/xml';
import yaml from 'highlight.js/lib/languages/yaml';

const LANGUAGES = {
  bash,
  css,
  elixir,
  go,
  javascript,
  json,
  python,
  ruby,
  rust,
  sql,
  typescript,
  xml,
  yaml,
  js: javascript,
  ts: typescript,
  html: xml,
  sh: bash,
  shell: bash,
  yml: yaml,
  ex: elixir,
  exs: elixir,
  py: python,
  rb: ruby,
  rs: rust,
};

Object.entries(LANGUAGES).forEach(([name, language]) => hljs.registerLanguage(name, language));

export function highlightIn(root: ParentNode) {
  root.querySelectorAll<HTMLElement>('code[data-code]:not(.hljs)').forEach((el) => {
    const language = el.dataset.lang;
    const text = el.textContent;

    const result =
      language && hljs.getLanguage(language)
        ? hljs.highlight(text, { language })
        : hljs.highlightAuto(text);

    el.innerHTML = result.value;
    el.classList.add('hljs');
  });
}
