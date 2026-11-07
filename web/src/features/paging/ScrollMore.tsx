import { useEffect, useEffectEvent, useRef, useState } from 'react';

import type { Result } from '@/data/gateway';
import { Button } from '@/design-system';

import './ScrollMore.css';

/**
 * Sits at the end of a paged list and loads the next page as it scrolls near. Watching starts again
 * after each page so a list that still ends on screen keeps filling until the server has no more
 */
export function ScrollMore({
  id,
  more,
}: {
  readonly id: string;
  readonly more: () => Promise<Result>;
}) {
  const end = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useEffectEvent(async () => {
    setLoading(true);

    try {
      const r = await more();
      setError(r.ok ? null : r.error);
    } finally {
      setLoading(false);
    }
  });

  useEffect(() => {
    const el = end.current;

    if (!el || loading || error) return;

    const near = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) void load();
      },
      { rootMargin: '600px 0px' },
    );

    near.observe(el);

    return () => near.disconnect();
  }, [loading, error]);

  return (
    <div ref={end} id={id} className="scroll-more" aria-busy={loading}>
      {loading ? <span className="loading-dots" aria-hidden="true" /> : null}

      {error ? (
        <>
          <span className="small subtle" role="alert">
            {error}
          </span>
          <Button size="tiny" variant="borderless" onClick={() => setError(null)}>
            Try again
          </Button>
        </>
      ) : null}
    </div>
  );
}
