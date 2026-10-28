import { useState } from 'react';
import {
  Button,
  CommunityMark,
  EmptyState,
  Icon,
  Select,
  type SelectOption,
} from '@/design-system';
import { useAppState } from '@/data/store';
import { cap, plural } from '@/domain/format';
import { community } from '@/domain/selectors';
import type { ModLogEntry } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PersonAvatar, PersonName } from '@/shell/people';

type Filter = 'all' | ModLogEntry['action'];

const FILTERS: { value: Filter; label: string }[] = [
  { value: 'all', label: 'Everything' },
  { value: 'removed', label: 'Removed' },
  { value: 'kept', label: 'Kept' },
  { value: 'banned', label: 'Banned' },
  { value: 'pinned', label: 'Pinned' },
  { value: 'changed', label: 'Changed' },
  { value: 'queued', label: 'Queued' },
];

export function LogTab({
  cid,
  name,
  withQueue,
  publicView,
}: {
  readonly cid: string;
  readonly name: string;
  readonly withQueue: boolean;
  readonly publicView?: boolean | undefined;
}) {
  const flash = useUi((s) => s.flash);
  const [filter, setFilter] = useState<Filter>('all');

  const all = useAppState((state) => state.modlog.filter((l) => l.c === cid));
  const entries = filter === 'all' ? all : all.filter((l) => l.action === filter);

  const mark = useAppState((state) => {
    const c = community(state, cid);
    return { hue: c?.hue ?? 'ink', letter: c?.letter ?? '?', logo: c?.logo ?? null };
  });

  const options: SelectOption<Filter>[] = FILTERS.map((f) => ({
    ...f,
    hint: cap(f.value === 'all' ? all.length : all.filter((l) => l.action === f.value).length),
    count: true,
  }));

  const copyLink = () =>
    navigator.clipboard.writeText(window.location.origin + routes.log(cid)).then(
      () => flash('Public link copied'),
      () => flash('Copy the address from the bar'),
    );

  return (
    <section className="grid gap-3" id="mod-log">
      {!withQueue && !publicView ? (
        <p className="mod-note">
          <Icon name="shield" />
          <span>
            This community isn't moderated, so nothing can be reported and there's no queue.
            Moderators can still remove things and ban people straight from the post, reply or
            message, and every action lands in this log.
          </span>
        </p>
      ) : null}

      <div className="mod-logbar">
        <div className="grid">
          <strong>{plural(entries.length, 'entry', 'entries')}</strong>
          <span className="x-small subtle">Public, so everyone can see what moderators do</span>
        </div>

        <div className="flex items-center gap-2" style={{ flex: 'none' }}>
          <Button size="small" onClick={() => void copyLink()} data-tip="Anyone can read this log">
            <Icon name="link" />
            Public link
          </Button>
          <Select value={filter} options={options} onChange={setFilter} label="Filter the log" />
        </div>
      </div>

      <div className="panel" style={{ paddingBlock: '0.4rem' }}>
        {entries.map((l) => (
          <div key={l.id} className="log-entry">
            <PersonAvatar id={l.who} size="sm" />

            <div>
              <p className="small">
                <strong>
                  <PersonName id={l.who} />
                </strong>{' '}
                <span>{l.text}</span>
              </p>
              {l.reason ? <p className="x-small subtle">Reason: {l.reason}</p> : null}
            </div>

            <div className="grid justify-items-end gap-1">
              <CommunityMark hue={mark.hue} letter={mark.letter} logo={mark.logo} size="1.2rem" />
              <span className="x-small subtle">{l.age}</span>
            </div>
          </div>
        ))}

        {!entries.length ? (
          <EmptyState
            art={filter === 'all' ? 'queue' : 'filter'}
            title={filter === 'all' ? 'Nothing logged yet' : 'Nothing logged for that'}
            text={
              filter === 'all'
                ? `Removals, bans and changes in ${name} show up here for everyone to see.`
                : 'Pick another action above, or Everything.'
            }
          />
        ) : null}
      </div>
    </section>
  );
}
