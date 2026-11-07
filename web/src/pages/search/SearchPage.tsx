import { useEffect, useRef, useState } from 'react';
import { useLocation, useSearchParams } from 'react-router';

import { useGateway } from '@/app/gateway-context';
import { ok, type Result } from '@/data/gateway';
import { useAppState } from '@/data/store';
import { cn, EmptyState, Icon, Measure, Select, Skeleton } from '@/design-system';
import { markMatches, searchWords } from '@/domain/search';
import { joinedCids } from '@/domain/selectors';
import type { SearchHit } from '@/domain/types';
import { ScrollMore } from '@/features/paging/ScrollMore';
import { PostRow } from '@/pages/shared/PostRow';
import { PageHeader } from '@/shell/PageHeader';

import './SearchPage.css';

const TYPING_DELAY_MS = 300;

type Found =
  | {
      readonly key: string;
      readonly ok: true;
      readonly hits: SearchHit[];
      readonly after: string | null;
    }
  | { readonly key: string; readonly ok: false; readonly error: string };

export function SearchPage() {
  const location = useLocation();

  // A search opened from Jump to anything while already here starts fresh
  return <SearchScreen key={location.key} />;
}

function SearchScreen() {
  const gateway = useGateway();
  const [params] = useSearchParams();
  const [asked, setAsked] = useState(() => ({ q: params.get('q') ?? '', c: params.get('c') }));
  const [text, setText] = useState(asked.q);
  const [found, setFound] = useState<Found | null>(null);
  const typing = useRef<number | null>(null);

  // Joined so retyping the same words doesn't search again
  const terms = searchWords(asked.q).join(' ');
  const words = terms ? terms.split(' ') : [];
  const cid = asked.c;
  const key = `${cid ?? ''} ${terms}`;

  useEffect(() => {
    if (!terms) return;

    let current = true;
    const asking = `${cid ?? ''} ${terms}`;

    void gateway.posts.search(terms, cid).then((r) => {
      if (!current) return;
      setFound(
        r.ok ? { key: asking, ok: true, ...r.value } : { key: asking, ok: false, error: r.error },
      );
    });

    return () => {
      current = false;
    };
  }, [gateway, terms, cid]);

  // A page that arrives after the words changed belongs to the old search and is dropped
  const more = async (): Promise<Result> => {
    if (!found?.ok || !found.after) return ok(undefined);

    const asking = found.key;
    const r = await gateway.posts.search(terms, cid, found.after);

    if (!r.ok) return r;

    setFound((now) =>
      now?.ok && now.key === asking
        ? { ...now, hits: [...now.hits, ...newHits(now.hits, r.value.hits)], after: r.value.after }
        : now,
    );

    return ok(undefined);
  };

  const show = (next: { q?: string; c?: string | null }) => {
    const q = next.q ?? asked.q;
    const c = next.c === undefined ? asked.c : next.c;
    const search = new URLSearchParams({ ...(q ? { q } : {}), ...(c ? { c } : {}) }).toString();

    setAsked({ q, c });

    // The address stays shareable without a router navigation that would reload every loader on screen
    window.history.replaceState(
      window.history.state,
      '',
      search ? `?${search}` : window.location.pathname,
    );
  };

  const type = (value: string) => {
    setText(value);

    if (typing.current !== null) window.clearTimeout(typing.current);

    typing.current = window.setTimeout(() => show({ q: value.trim() }), TYPING_DELAY_MS);
  };

  return (
    <>
      <PageHeader label="Search" title="Search" noindex />

      <main id="main">
        <Measure narrow className="grid gap-4">
          <SearchBar
            text={text}
            cid={cid}
            onText={type}
            onCommunity={(c) => show({ c: c === 'all' ? null : c })}
          />

          <SearchResults words={words} found={found} stale={found?.key !== key} more={more} />
        </Measure>
      </main>
    </>
  );
}

function SearchBar({
  text,
  cid,
  onText,
  onCommunity,
}: {
  readonly text: string;
  readonly cid: string | null;
  readonly onText: (value: string) => void;
  readonly onCommunity: (cid: string) => void;
}) {
  const cids = useAppState(joinedCids);

  const names = useAppState((state) =>
    joinedCids(state).map((c) => state.communities[c]?.name ?? c),
  );

  const options = [
    { value: 'all', label: 'All communities' },
    ...cids.map((c, i) => ({ value: c, label: names[i] ?? c })),
  ];

  return (
    <div className="search-bar">
      <label className="search-bar__box">
        <span className="search-bar__icon">
          <Icon name="search" />
        </span>
        <input
          className="input"
          id="search-q"
          type="search"
          value={text}
          onChange={(e) => onText(e.target.value)}
          placeholder="Search posts and replies"
          aria-label="Search posts and replies"
          autoComplete="off"
          spellCheck={false}
        />
      </label>

      <div className="search-bar__filter">
        <Select value={cid ?? 'all'} options={options} onChange={onCommunity} label="Community" />
      </div>
    </div>
  );
}

const newHits = (known: readonly SearchHit[], next: readonly SearchHit[]) => {
  const ids = new Set(known.map((h) => h.id));

  return next.filter((h) => !ids.has(h.id));
};

function SearchResults({
  words,
  found,
  stale,
  more,
}: {
  readonly words: readonly string[];
  readonly found: Found | null;
  readonly stale: boolean;
  readonly more: () => Promise<Result>;
}) {
  if (!words.length)
    return (
      <EmptyState
        art="search"
        title="Search everything you can read"
        text="Find posts and replies in your communities."
      />
    );

  // Earlier results stay while the next search runs so only the very first one shows shapes
  if (!found) return <Skeleton kind="feed" />;

  if (!found.ok) return <EmptyState art="broken" title="Search isn't working" text={found.error} />;

  if (!found.hits.length)
    return (
      <EmptyState
        art="search"
        title="Nothing matches that"
        text="Try fewer words, or the start of a word you remember."
      />
    );

  return (
    <section
      className={cn('feed search-results', stale && 'is-stale')}
      id="search-results"
      aria-live="polite"
      aria-busy={stale}
    >
      {found.hits.map((hit) => (
        <SearchResult key={hit.id} hit={hit} words={words} />
      ))}

      {found.after && !stale ? <ScrollMore id="search-more" more={more} /> : null}
    </section>
  );
}

function SearchResult({
  hit,
  words,
}: {
  readonly hit: SearchHit;
  readonly words: readonly string[];
}) {
  const post = useAppState((state) => state.posts.find((p) => p.id === hit.id));

  if (!post) return null;

  const excerpt = hit.excerpt ? (
    <p className="post-row__excerpt search-hit">
      {hit.reply ? <span className="search-hit__where">In a reply </span> : null}
      {markMatches(hit.excerpt, words).map((part) =>
        part.hit ? <mark key={part.at}>{part.text}</mark> : part.text,
      )}
    </p>
  ) : null;

  return <PostRow post={post} showCommunity excerpt={excerpt} />;
}
