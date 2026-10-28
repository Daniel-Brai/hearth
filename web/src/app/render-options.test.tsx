// @vitest-environment node
import { Suspense, use } from 'react';
import { renderToReadableStream } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { RENDER_OPTIONS } from './render-options';

function Big({ text }: { readonly text: Promise<string> }) {
  return <p>{use(text)}</p>;
}

async function render(options: { readonly progressiveChunkSize?: number }): Promise<string> {
  const text = new Promise<string>((resolve) => setTimeout(() => resolve('x'.repeat(60_000)), 5));

  const stream = await renderToReadableStream(
    <main>
      <Suspense fallback="Loading">
        <Big text={text} />
      </Suspense>
    </main>,
    options,
  );

  await stream.allReady;

  return new Response(stream).text();
}

describe('RENDER_OPTIONS', () => {
  it('would leave a large section to be moved in later without them', async () => {
    expect(await render({})).toContain('id="S:0"');
  });

  it('keeps every section in place, with nothing for the browser to move', async () => {
    const html = await render(RENDER_OPTIONS);

    expect(html).not.toContain('id="S:');
    expect(html).not.toContain('$RC');
    expect(html).toContain('x'.repeat(60_000));
  });
});
