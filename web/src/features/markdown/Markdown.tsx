import { useEffect, useMemo, useRef } from 'react';
import { useAppState, useStore } from '@/data/store';
import type { Attachment } from '@/domain/types';
import { cn } from '@/design-system/index';
import { wireCarousels } from './carousel-block';
import { lexMarkdown, markdownKey, renderInline, renderMarkdown } from './markdown';

const joined = (text: string | readonly string[]) =>
  Array.isArray(text) ? text.join('\n\n') : String(text);

function useMarkdownKey(text: string | readonly string[], community: string | null) {
  const refs = useMemo(() => {
    const { mentions, refs: rooms } = lexMarkdown(joined(text));
    return { mentions, refs: rooms };
  }, [text]);

  return useAppState((state) => markdownKey(state, refs, community));
}

export function Markdown({
  text,
  community,
  files,
  className,
}: {
  readonly text: string | readonly string[];
  readonly community: string | null;
  readonly files?: readonly Attachment[];
  readonly className?: string;
}) {
  const root = useRef<HTMLDivElement>(null);
  const key = useMarkdownKey(text, community);
  const store = useStore();

  const html = useMemo(() => {
    const state = store.get();
    return renderMarkdown(text, files ? { state, community, files } : { state, community });
    // The key stands in for the store parts this text depends on
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text, community, files, key]);

  useEffect(() => {
    const el = root.current;
    if (!el?.querySelector('code[data-code]:not(.hljs)')) return;

    void import('./highlight').then(({ highlightIn }) => highlightIn(el));
  }, [html]);

  useEffect(() => {
    const el = root.current;
    if (!el?.querySelector('[data-carousel]')) return;

    return wireCarousels(el);
  }, [html]);

  return (
    <div ref={root} className={cn('md', className)} dangerouslySetInnerHTML={{ __html: html }} />
  );
}

export function InlineMarkdown({
  text,
  community,
  noLinks,
  className,
  as: Tag = 'span',
}: {
  readonly text: string | readonly string[];
  readonly community: string | null;
  readonly noLinks?: boolean;
  readonly className?: string;
  readonly as?: 'span' | 'p';
}) {
  const key = useMarkdownKey(text, community);
  const store = useStore();

  const html = useMemo(
    () => renderInline(text, { state: store.get(), community }, noLinks),
    // The key stands in for the store parts this text depends on
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [text, community, noLinks, key],
  );

  return <Tag className={cn('md-inline', className)} dangerouslySetInnerHTML={{ __html: html }} />;
}
