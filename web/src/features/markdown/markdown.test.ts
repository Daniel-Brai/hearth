import { describe, expect, it } from 'vitest';
import { emptyState } from '@/data/empty-state';
import { plainText } from './plain-text';
import { codeBlockClick } from './code-block';
import { wireCarousels } from './carousel-block';
import { CODE_COLLAPSE_AFTER, renderInline, renderMarkdown } from './markdown';

const state = emptyState();

const files = [
  { id: 'a1', name: 'sunset.png', kind: 'image' as const, size: 10, url: '/sunset.png' },
  { id: 'a2', name: 'beach.png', kind: 'image' as const, size: 10, url: '/beach.png' },
  { id: 'a3', name: 'notes.pdf', kind: 'file' as const, size: 10, url: '/notes.pdf' },
];

describe('images in markdown', () => {
  it('leaves images out of one line excerpts instead of calling them removed', () => {
    const html = renderInline('Hi there\n\n![sunset.png](attachment:a1)', {
      state,
      community: null,
    });

    expect(html).toBe('Hi there');
  });

  it('still renders images in full posts after an excerpt was drawn', () => {
    renderInline('![sunset.png](attachment:a1)', { state, community: null });

    const html = renderMarkdown('![sunset.png](attachment:a1#right)', {
      state,
      community: null,
      files,
    });

    expect(html).toContain('md-image--right');
    expect(html).not.toContain('was removed');
  });

  it('keeps file names out of plain text', () => {
    expect(plainText('Look ![sunset.png](attachment:a1) here')).toBe('Look here');
  });
});

describe('code blocks', () => {
  const fence = (lines: number) =>
    '```ts\n' +
    Array.from({ length: lines }, (_, i) => `const line${i} = ${i};`).join('\n') +
    '\n```';

  const mount = (lines: number) => {
    document.body.innerHTML = renderMarkdown(fence(lines), { state, community: null });
    return document.querySelector<HTMLElement>('.code-block')!;
  };

  it('leaves a short block open with no toggle', () => {
    const block = mount(CODE_COLLAPSE_AFTER);

    expect(block.hasAttribute('data-long')).toBe(false);
    expect(block.querySelector('[data-code-toggle]')).toBeNull();
  });

  it('collapses a long block and says how many lines it has', () => {
    const block = mount(CODE_COLLAPSE_AFTER + 5);
    const toggle = block.querySelector('[data-code-toggle]')!;

    expect(block.hasAttribute('data-long')).toBe(true);
    expect(toggle.textContent).toContain(`Show all ${CODE_COLLAPSE_AFTER + 5} lines`);
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
  });

  it('expands a long block and collapses it again', () => {
    const block = mount(CODE_COLLAPSE_AFTER + 5);
    const toggle = block.querySelector<HTMLElement>('[data-code-toggle]')!;

    document.addEventListener('click', codeBlockClick);

    toggle.click();
    expect(block.hasAttribute('data-expanded')).toBe(true);
    expect(toggle.getAttribute('aria-expanded')).toBe('true');

    toggle.click();
    expect(block.hasAttribute('data-expanded')).toBe(false);
    expect(toggle.getAttribute('aria-expanded')).toBe('false');

    document.removeEventListener('click', codeBlockClick);
  });
});

describe('carousels', () => {
  const two = '![sunset.png](attachment:a1#left)\n![beach.png](attachment:a2)';

  const mount = (text: string) => {
    document.body.innerHTML = `<div class="md">${renderMarkdown(text, { state, community: null, files })}</div>`;
    return document.querySelector<HTMLElement>('.md')!;
  };

  it('shows images on their own lines as one carousel placed by the first', () => {
    const root = mount(two);
    const carousel = root.querySelector('[data-carousel]')!;

    expect(carousel.classList).toContain('md-carousel--left');
    expect(carousel.querySelectorAll('.carousel__image')).toHaveLength(2);
    expect(carousel.getAttribute('tabindex')).toBe('0');
    expect(root.querySelector('.md-image')).toBeNull();
  });

  it('keeps separate paragraphs as separate images', () => {
    const root = mount('![sunset.png](attachment:a1)\n\n![beach.png](attachment:a2)');

    expect(root.querySelector('[data-carousel]')).toBeNull();
    expect(root.querySelectorAll('.md-image')).toHaveLength(2);
  });

  it('does not make a carousel when text or a file sits with the images', () => {
    expect(mount(`${two}\nLook`).querySelector('[data-carousel]')).toBeNull();
    expect(
      mount('![sunset.png](attachment:a1)\n![notes.pdf](attachment:a3)').querySelector(
        '[data-carousel]',
      ),
    ).toBeNull();
  });

  it('steps with the buttons and the arrow keys', () => {
    const root = mount(two);
    const stop = wireCarousels(root);
    const carousel = root.querySelector<HTMLElement>('[data-carousel]')!;
    const next = carousel.querySelector<HTMLButtonElement>('.carousel__next')!;
    const count = carousel.querySelector('.carousel__count')!;

    next.click();

    expect(count.textContent).toBe('2 / 2');
    expect(next.disabled).toBe(true);

    carousel.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true }));

    expect(count.textContent).toBe('1 / 2');
    expect(carousel.querySelector<HTMLButtonElement>('.carousel__prev')!.disabled).toBe(true);

    stop();
  });
});
