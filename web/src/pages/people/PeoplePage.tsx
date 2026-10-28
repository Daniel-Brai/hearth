import { useState } from 'react';
import { useNavigate } from 'react-router';
import { Badge, Button, cn, Icon, Label, Link, Select } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { cap, plural } from '@/domain/format';
import { canDo, displayName, handle, joinedCids, person, presence } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { PersonAvatar } from '@/shell/people';
import { PeopleEmpty } from './PeopleEmpty';
import { directUnread, lastDmLine, peopleIds, sharedNames, sharedSummary } from './people-select';
import './PeoplePage.css';

export function PeoplePage() {
  const gateway = useGateway();
  const navigate = useNavigate();

  useLoad(() => gateway.load.people(), 'people');

  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('all');

  const ids = useAppState((state) => peopleIds(state, query, filter));
  const directs = useAppState((state) => state.directs.map((d) => d.who));
  const firstUsername = useAppState((state) => (ids[0] ? person(state, ids[0]).username : null));

  const searching = query.trim() !== '';
  const showDirects = !searching && filter === 'all' && directs.length > 0;

  const heading = searching ? plural(ids.length, 'person', 'people') : 'Everyone';

  const message = (id: string, username: string) => {
    gateway.chat.openDm(id);
    void navigate(routes.dm(username));
  };

  const openFirst = () => {
    const id = ids[0];
    if (id && firstUsername) message(id, firstUsername);
  };

  return (
    <>
      <PageHeader label="People" title="People" />

      <main id="main">
        <div className="measure measure--narrow grid gap-4">
          <PeopleSearch
            query={query}
            onQuery={setQuery}
            onSubmit={openFirst}
            filter={filter}
            onFilter={setFilter}
          />

          {showDirects ? (
            <section className="grid gap-2" aria-label="Your chats">
              <Label>Your chats</Label>

              <div className="people-rows" id="direct-rows">
                {directs.map((who) => (
                  <DirectRow key={who} who={who} />
                ))}
              </div>
            </section>
          ) : null}

          <section className="grid gap-2" aria-label="Everyone">
            {ids.length && (searching || showDirects) ? <Label>{heading}</Label> : null}

            <div className="people-rows" id="people-rows">
              {ids.map((id) => (
                <PersonRow key={id} id={id} onMessage={message} />
              ))}

              {ids.length ? null : <EmptyPeople searching={searching} filter={filter} />}
            </div>
          </section>
        </div>
      </main>
    </>
  );
}

function EmptyPeople({
  searching,
  filter,
}: {
  readonly searching: boolean;
  readonly filter: string;
}) {
  const canInvite = useAppState(
    (state) => filter !== 'all' && canDo(state, filter, 'invite.create'),
  );

  return <PeopleEmpty searching={searching} filter={filter} canInvite={canInvite} />;
}

function PeopleSearch({
  query,
  onQuery,
  onSubmit,
  filter,
  onFilter,
}: {
  readonly query: string;
  readonly onQuery: (value: string) => void;
  readonly onSubmit: () => void;
  readonly filter: string;
  readonly onFilter: (value: string) => void;
}) {
  const cids = useAppState(joinedCids);

  const names = useAppState((state) =>
    joinedCids(state).map((cid) => state.communities[cid]?.name ?? cid),
  );

  const options = [
    { value: 'all', label: 'All communities' },
    ...cids.map((cid, i) => ({ value: cid, label: names[i] ?? cid })),
  ];

  return (
    <div className="people-search">
      <label className="people-search__box">
        <span className="people-search__icon">
          <Icon name="search" />
        </span>
        <input
          className="input"
          id="people-q"
          type="search"
          value={query}
          onChange={(e) => onQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key !== 'Enter') return;
            e.preventDefault();
            onSubmit();
          }}
          placeholder="Search by name or @username"
          aria-label="Search people"
          autoComplete="off"
          spellCheck={false}
        />
      </label>

      <div className="people-search__filter">
        <Select value={filter} options={options} onChange={onFilter} label="Community" />
      </div>
    </div>
  );
}

function DirectRow({ who }: { readonly who: string }) {
  const view = useAppState((state) => ({
    name: displayName(state, who),
    username: person(state, who).username,
    line: lastDmLine(state, who),
    unread: directUnread(state, who),
    presence: presence(state, who)?.label ?? null,
  }));

  return (
    <Link className={cn('people-row', view.unread > 0 && 'unread')} to={routes.dm(view.username)}>
      <PersonAvatar id={who} online="auto" />

      <span className="people-row__main">
        <strong className="truncate">{view.name}</strong>
        <span className="small subtle truncate">{view.line}</span>
      </span>

      <span className="people-row__meta">
        {view.presence ? <span className="x-small subtle">{view.presence}</span> : null}
        {view.unread > 0 ? (
          <Badge red count={view.unread} aria-label={`${cap(view.unread)} unread`} />
        ) : null}
      </span>
    </Link>
  );
}

function PersonRow({
  id,
  onMessage,
}: {
  readonly id: string;
  readonly onMessage: (id: string, username: string) => void;
}) {
  const view = useAppState((state) => {
    const name = displayName(state, id);
    const at = handle(state, id);
    const shared = sharedNames(state, id);
    const { shown, more } = sharedSummary(shared);

    return {
      name,
      username: person(state, id).username,
      sub: [name === at ? null : at, shown].filter((s): s is string => !!s).join(' · '),
      more,
      all: more ? shared.join(', ') : null,
    };
  });

  return (
    <div className="people-row">
      <PersonAvatar id={id} size="md" link online="auto" />

      <Link className="people-row__main" to={routes.profile(view.username)}>
        <strong className="truncate">{view.name}</strong>
        <span className="people-row__sub small subtle" title={view.all ?? undefined}>
          <span className="truncate">{view.sub}</span>
          {view.more ? <span className="flex-none">and {view.more} more</span> : null}
        </span>
      </Link>

      <Button size="small" onClick={() => onMessage(id, view.username)}>
        <Icon name="chat" />
        Message
      </Button>
    </div>
  );
}
