import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { Badge, cn, Dialog, EmptyState, Icon, Keys, Link } from '@/design-system';
import { useAppState } from '@/data/store';
import type { AppState } from '@/domain/app-state';
import {
  canDo,
  displayName,
  handle,
  isInstanceAdmin,
  isMod,
  joinedCids,
  pendingRequests,
  person,
  postHref,
  voiceOn,
} from '@/domain/selectors';
import { recentJumps, rememberJump } from '@/runtime/jump-recent';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PersonAvatar } from '@/shell/people';
import { useRouteContext } from '@/shell/use-route-context';
import './JumpDialog.css';

type Item = {
  readonly href: string;
  readonly label: string;
  readonly group: string;
  readonly icon: ReactNode;
  readonly hint: string | null;
  readonly search: string | null;
  readonly count: number | null;
  readonly live: boolean;
};

const icon = (name: Parameters<typeof Icon>[0]['name']) => <Icon name={name} />;

function buildIndex(state: AppState): Item[] {
  const items: Item[] = [];

  const add = (i: Partial<Item> & Pick<Item, 'href' | 'label' | 'group' | 'icon'>) =>
    items.push({ hint: null, search: null, count: null, live: false, ...i });

  add({ href: routes.home, label: 'Catch up', group: 'Go to', icon: icon('inbox'), hint: 'Home' });

  add({
    href: routes.people,
    label: 'People',
    group: 'Go to',
    icon: icon('users'),
    hint: 'Messages',
  });

  add({ href: routes.events, label: 'Events', group: 'Go to', icon: icon('calendar') });
  add({ href: routes.settings, label: 'Settings', group: 'Go to', icon: icon('gear') });

  if (state.me)
    add({
      href: routes.profile(person(state, state.me).username),
      label: 'Your profile',
      group: 'Go to',
      icon: icon('user'),
    });

  add({ href: routes.newPost, label: 'Write a post', group: 'Go to', icon: icon('pencil') });

  if (isInstanceAdmin(state)) {
    add({
      href: routes.requests,
      label: 'Community requests',
      group: 'Go to',
      icon: icon('inbox'),
      count: pendingRequests(state).length || null,
    });
  }

  Object.entries(state.communities).forEach(([cid, c]) => {
    if (!c.joined && c.visibility === 'invite') return;

    add({
      href: routes.community(cid),
      label: c.name,
      group: 'Communities',
      icon: icon('globe'),
      hint: c.tagline,
      search: c.tagline,
    });

    if (!c.joined) return;

    c.rooms.forEach((r) =>
      add({
        href: routes.chat(cid, r.id),
        label: '#' + r.name,
        group: 'Rooms',
        icon: icon(r.access === 'roles' ? 'lock' : 'hash'),
        hint: c.name,
        search: c.name,
        count: r.unread || null,
      }),
    );

    (voiceOn(state) ? c.voice : []).forEach((v) =>
      add({
        href: routes.voice(cid, v.id),
        label: v.name,
        group: 'Rooms',
        icon: icon(v.access === 'roles' ? 'lock' : 'volume'),
        hint: c.name + (v.live ? ' · live' : ''),
        search: c.name,
        count: v.live ? v.listeners : null,
        live: v.live,
      }),
    );

    add({
      href: routes.communityEvents(cid),
      label: 'Events in ' + c.name,
      group: 'Manage',
      icon: icon('calendar'),
      search: c.name + ' events',
    });

    if (canDo(state, cid, 'invite.create'))
      add({
        href: routes.invite(cid),
        label: 'Invite people to ' + c.name,
        group: 'Manage',
        icon: icon('invite'),
        search: c.name + ' invite',
      });

    if (isMod(state, cid))
      add({
        href: routes.moderation(cid),
        label: 'Moderation in ' + c.name,
        group: 'Manage',
        icon: icon('shield'),
        search: c.name + ' moderation mod',
      });

    if (canDo(state, cid, 'role.update'))
      add({
        href: routes.roles(cid),
        label: 'Roles in ' + c.name,
        group: 'Manage',
        icon: icon('roles'),
        search: c.name + ' roles',
      });
  });

  state.events
    .filter((e) => state.communities[e.c]?.joined)
    .forEach((e) =>
      add({
        href: routes.event(e.c, e.id, e.title),
        label: e.title,
        group: 'Events',
        icon: icon('calendar'),
        hint: state.communities[e.c]!.name,
        search: state.communities[e.c]!.name,
      }),
    );

  state.posts
    .filter((p) => state.communities[p.c]?.joined)
    .forEach((p) =>
      add({
        href: postHref(p),
        label: p.title,
        group: 'Posts',
        icon: icon('scroll'),
        hint: state.communities[p.c]!.name,
        search:
          p.tags.map((t) => '#' + t).join(' ') + ' ' + p.kind + ' ' + state.communities[p.c]!.name,
      }),
    );

  Object.keys(state.people).forEach((id) => {
    if (id === state.me) return;
    add({
      href: routes.profile(person(state, id).username),
      label: displayName(state, id),
      group: 'People',
      icon: <PersonAvatar id={id} size="xs" />,
      hint: handle(state, id),
      search: handle(state, id),
    });
  });

  const tags = new Set<string>();

  state.posts.forEach(
    (p) => state.communities[p.c]?.joined && p.tags.forEach((t) => tags.add(p.c + '/' + t)),
  );

  tags.forEach((key) => {
    const [cid, tag] = key.split('/') as [string, string];
    add({
      href: routes.tag(cid, tag),
      label: '#' + tag,
      group: 'Tags',
      icon: icon('tag'),
      hint: state.communities[cid]!.name,
      search: state.communities[cid]!.name,
    });
  });

  return items;
}

const MANAGE_WORDS = ['mod', 'moder', 'role', 'invit'];

export function JumpDialog() {
  const closeDialog = useUi((s) => s.closeDialog);
  const navigate = useNavigate();
  const { community } = useRouteContext();
  const state = useAppState();

  const [query, setQuery] = useState('');
  const [index, setIndex] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  const list = useRef<HTMLDivElement>(null);

  const all = useMemo(() => buildIndex(state), [state]);
  const joined = joinedCids(state);

  const items = useMemo(() => {
    const words = query.trim().toLowerCase().replace('@', '').split(' ').filter(Boolean);

    if (words.length) {
      const hay = (i: Item) =>
        [i.label, i.search, i.group !== 'People' ? i.hint : null]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
      const score = (i: Item) =>
        (i.label.toLowerCase().startsWith(words[0]!) ? 0 : 1) + (i.group === 'Manage' ? 0 : 0.5);
      return all
        .filter((i) => {
          const text = hay(i);
          return words.every((w) => text.includes(w));
        })
        .sort((a, b) => score(a) - score(b))
        .slice(0, 40);
    }

    const items = new Map<string, Item>();

    for (const i of all) if (!items.has(i.href)) items.set(i.href, i);

    const byHref = (h: string) => items.get(h);

    const recent = recentJumps()
      .map(byHref)
      .filter((i): i is Item => !!i)
      .slice(0, 5)
      .map((i) => ({ ...i, group: 'Recent' }));

    const here: Item[] = [];
    const c = community ? state.communities[community] : undefined;

    if (community && c?.joined) {
      const pick = (href: string, label: string) => {
        const it = byHref(href);
        if (it && !recent.some((r) => r.href === href))
          here.push({ ...it, group: 'In ' + c.name, label });
      };

      pick(routes.community(community), 'Feed');
      pick(routes.communityEvents(community), 'Events');
      pick(routes.moderation(community), 'Moderation');
      pick(routes.roles(community), 'Roles');
      pick(routes.invite(community), 'Invite people');
    }

    const go = all.filter((i) => i.group === 'Go to' && !recent.some((r) => r.href === i.href));

    return [...recent, ...here, ...go].slice(0, 40);
  }, [all, query, community, state]);

  const groups = useMemo(() => {
    const out: { title: string; items: (Item & { index: number })[] }[] = [];
    items.forEach((it, i) => {
      let g = out.find((x) => x.title === it.group);

      if (!g) {
        g = { title: it.group, items: [] };
        out.push(g);
      }

      g.items.push({ ...it, index: i });
    });
    return out;
  }, [items]);

  useEffect(() => {
    input.current?.focus();
  }, []);

  useEffect(() => {
    list.current
      ?.querySelector('.jump__item[aria-selected="true"]')
      ?.scrollIntoView({ block: 'nearest' });
  }, [index]);

  const close = () => closeDialog('jump');

  const go = (it: Item) => {
    rememberJump(it.href);
    close();
    void navigate(it.href);
  };

  const move = (d: number) => {
    if (items.length) setIndex((i) => (i + d + items.length) % items.length);
  };

  const emptyText = MANAGE_WORDS.some((w) => query.toLowerCase().includes(w))
    ? 'Moderation, roles and invites only show for communities where your role allows them.'
    : "Try a community, a #room, a #tag, someone's @username, or an action like “moderation elixir”.";

  void joined;

  return (
    <Dialog open onClose={close} className="dialog--jump" label="Jump to">
      <div className="jump__field">
        <Icon name="search" />
        <input
          ref={input}
          className="jump__input"
          id="jump-input"
          type="search"
          placeholder="Communities, rooms, posts, people, #tags"
          aria-label="Jump to anything"
          autoComplete="off"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setIndex(0);
          }}
          onKeyDown={(e) => {
            if (e.key === 'ArrowDown') {
              e.preventDefault();
              move(1);
            } else if (e.key === 'ArrowUp') {
              e.preventDefault();
              move(-1);
            } else if (e.key === 'Enter') {
              e.preventDefault();
              const it = items[index];
              if (it) go(it);
            }
          }}
        />
        <Keys combo="esc" />
      </div>

      <div className="jump__results" ref={list}>
        {groups.map((group) => (
          <div key={group.title}>
            <div className="jump__section">{group.title}</div>

            {group.items.map((item) => (
              <Link
                key={item.href + item.label}
                className="jump__item"
                to={item.href}
                aria-selected={item.index === index}
                onMouseEnter={() => setIndex(item.index)}
                onClick={(e) => {
                  e.preventDefault();
                  go(item);
                }}
              >
                <span className="jump__icon">{item.icon}</span>
                <span className="truncate">{item.label}</span>
                {item.hint ? <span className={cn('jump__hint')}>{item.hint}</span> : null}
                {item.count ? (
                  <Badge
                    className="jump__count"
                    red={item.live}
                    count={item.count}
                    aria-label={item.live ? item.count + ' listening' : item.count + ' new'}
                  />
                ) : null}
              </Link>
            ))}
          </div>
        ))}

        {!items.length ? (
          <EmptyState small art="search" title="Nothing matches that" text={emptyText} />
        ) : null}
      </div>

      <div className="jump__foot kb-only">
        <span>
          <Keys combo="up" />
          <Keys combo="down" /> to move
        </span>
        <span>
          <Keys combo="enter" /> to open
        </span>
      </div>
    </Dialog>
  );
}
