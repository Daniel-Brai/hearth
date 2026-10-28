/** Blocks are HTML strings with no handlers so one listener sits on the document */
export function codeBlockClick(e: MouseEvent) {
  const target = e.target as Element | null;
  const copy = target?.closest?.('[data-copy-code]');

  if (copy) return copyCode(copy);

  const toggle = target?.closest?.('[data-code-toggle]');

  if (toggle) toggleCode(toggle);
}

function copyCode(btn: Element) {
  const code = btn.closest('.code-block')?.querySelector('code')?.innerText;

  if (!code) return;

  const done = () => {
    btn.classList.add('is-done');
    btn.setAttribute('data-tip', 'Copied');
    window.setTimeout(() => {
      btn.classList.remove('is-done');
      btn.setAttribute('data-tip', 'Copy code');
    }, 1400);
  };

  navigator.clipboard.writeText(code).then(done, done);
}

function toggleCode(btn: Element) {
  const block = btn.closest<HTMLElement>('.code-block');

  if (!block) return;

  const expanded = block.toggleAttribute('data-expanded');

  btn.setAttribute('aria-expanded', String(expanded));

  // Collapsing can leave the block top far above the screen
  if (!expanded && block.getBoundingClientRect().top < 0)
    block.scrollIntoView({ block: 'start', behavior: 'smooth' });
}
