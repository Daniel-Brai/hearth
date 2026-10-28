import { useOrigin } from '@/app/request-context';
import { useAppState } from '@/data/store';
import type { AppState } from '@/domain/app-state';
import { canSeeName, community as communityOf, person, photoOf } from '@/domain/selectors';
import type { CommunityEvent, Reply } from '@/domain/types';
import { plainText } from '@/features/markdown/plain-text';
import { routes } from '@/runtime/routes';

// Builders return null for communities that are invite only, private or noindex
type Thing = { readonly [key: string]: unknown };

type Crumb = { readonly name: string; readonly path: string };

const absolute = (origin: string, path: string) => new URL(path, origin || 'http://localhost').href;

export function indexable(state: AppState, cid: string): boolean {
  const c = communityOf(state, cid);

  return !!c && c.visibility === 'public' && c.indexed !== false;
}

export function breadcrumbList(origin: string, crumbs: readonly Crumb[]): Thing {
  return {
    '@type': 'BreadcrumbList',
    itemListElement: crumbs.map((crumb, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: crumb.name,
      item: absolute(origin, crumb.path),
    })),
  };
}

function personThing(state: AppState, id: string, origin: string): Thing {
  const p = person(state, id);

  return {
    '@type': 'Person',
    name: canSeeName(state, id) ? p.name : p.username,
    alternateName: '@' + p.username,
    url: absolute(origin, routes.profile(p.username)),
  };
}

const counter = (type: 'CommentAction' | 'LikeAction', count: number): Thing => ({
  '@type': 'InteractionCounter',
  interactionType: `https://schema.org/${type}`,
  userInteractionCount: count,
});

const dated = (key: string, at: string | undefined): Thing => (at ? { [key]: at } : {});

export function postGraph(state: AppState, id: string, origin: string): Thing[] | null {
  const p = state.posts.find((x) => x.id === id);

  if (!p || p.removed || !indexable(state, p.c)) return null;

  const c = communityOf(state, p.c)!;
  const url = absolute(origin, routes.post(p.c, p.id, p.title));
  const replies = p.replies.filter((r) => !r.removed);

  const answer = (r: Reply): Thing => ({
    '@type': 'Answer',
    text: plainText(r.body),
    author: personThing(state, r.who, origin),
    ...dated('dateCreated', r.at),
    upvoteCount: r.helpful,
    url: `${url}#reply-${r.id}`,
  });

  const crumbs = breadcrumbList(origin, [
    { name: c.name, path: routes.community(p.c) },
    { name: p.title, path: routes.post(p.c, p.id, p.title) },
  ]);

  if (p.kind === 'Question') {
    const accepted = replies.find((r) => r.id === p.answer);
    const suggested = replies.filter((r) => r.parent === null && r.id !== p.answer);

    return [
      {
        '@type': 'QAPage',
        url,
        mainEntity: {
          '@type': 'Question',
          name: p.title,
          text: plainText(p.body),
          author: personThing(state, p.author, origin),
          ...dated('dateCreated', p.at),
          answerCount: (accepted ? 1 : 0) + suggested.length,
          upvoteCount: p.helpful,
          ...(accepted ? { acceptedAnswer: answer(accepted) } : {}),
          ...(suggested.length ? { suggestedAnswer: suggested.map(answer) } : {}),
        },
      },
      crumbs,
    ];
  }

  return [
    {
      '@type': 'DiscussionForumPosting',
      headline: p.title,
      text: plainText(p.body),
      url,
      author: personThing(state, p.author, origin),
      ...dated('datePublished', p.at),
      interactionStatistic: [
        counter('CommentAction', replies.length),
        counter('LikeAction', p.helpful),
      ],
      comment: replies.map((r) => ({
        '@type': 'Comment',
        text: plainText(r.body),
        author: personThing(state, r.who, origin),
        ...dated('datePublished', r.at),
        url: `${url}#reply-${r.id}`,
        interactionStatistic: [counter('LikeAction', r.helpful)],
      })),
    },
    crumbs,
  ];
}

function eventLocation(state: AppState, e: CommunityEvent, origin: string): Thing {
  const where = e.where;

  if (where.type === 'link')
    return {
      '@type': 'VirtualLocation',
      url: where.url,
      ...(where.label ? { name: where.label } : {}),
    };

  const c = communityOf(state, e.c);
  const room = (where.type === 'voice' ? c?.voice : c?.rooms)?.find((r) => r.id === where.room);

  const path =
    where.type === 'voice' ? routes.voice(e.c, where.room) : routes.chat(e.c, where.room);

  return {
    '@type': 'VirtualLocation',
    url: absolute(origin, path),
    ...(room ? { name: room.name } : {}),
  };
}

export function eventGraph(state: AppState, id: string, origin: string): Thing[] | null {
  const e = state.events.find((x) => x.id === id);

  if (!e || !indexable(state, e.c)) return null;

  const c = communityOf(state, e.c)!;
  const end = new Date(new Date(e.start).getTime() + e.mins * 60_000).toISOString();

  return [
    {
      '@type': 'Event',
      name: e.title,
      ...(e.desc ? { description: plainText(e.desc) } : {}),
      startDate: e.start,
      endDate: end,
      eventStatus: `https://schema.org/${e.cancelled ? 'EventCancelled' : 'EventScheduled'}`,
      eventAttendanceMode: 'https://schema.org/OnlineEventAttendanceMode',
      location: eventLocation(state, e, origin),
      organizer: personThing(state, e.host, origin),
      url: absolute(origin, routes.event(e.c, e.id, e.title)),
    },
    breadcrumbList(origin, [
      { name: c.name, path: routes.community(e.c) },
      { name: 'Events', path: routes.communityEvents(e.c) },
      { name: e.title, path: routes.event(e.c, e.id, e.title) },
    ]),
  ];
}

export function eventsGraph(state: AppState, cid: string, origin: string): Thing[] | null {
  const c = communityOf(state, cid);
  if (!c || !indexable(state, cid)) return null;

  return [
    breadcrumbList(origin, [
      { name: c.name, path: routes.community(cid) },
      { name: 'Events', path: routes.communityEvents(cid) },
    ]),
  ];
}

export function profileGraph(state: AppState, id: string, origin: string): Thing[] | null {
  const p = state.people[id];

  if (!p) return null;

  const photo = photoOf(state, id);

  return [
    {
      '@type': 'ProfilePage',
      url: absolute(origin, routes.profile(p.username)),
      mainEntity: {
        ...personThing(state, id, origin),
        ...(p.bio ? { description: plainText(p.bio) } : {}),
        ...(photo && !photo.startsWith('data:') ? { image: absolute(origin, photo) } : {}),
      },
    },
    breadcrumbList(origin, [{ name: '@' + p.username, path: routes.profile(p.username) }]),
  ];
}

export function communityGraph(state: AppState, cid: string, origin: string): Thing[] | null {
  const c = communityOf(state, cid);

  if (!c || !indexable(state, cid)) return null;

  const posts = state.posts.filter((p) => p.c === cid && !p.removed).slice(0, 20);
  const image = c.banner ?? c.logo;

  return [
    {
      '@type': 'CollectionPage',
      name: c.name,
      ...(c.tagline ? { description: c.tagline } : {}),
      url: absolute(origin, routes.community(cid)),
      ...(image && !image.startsWith('data:') ? { image: absolute(origin, image) } : {}),
      mainEntity: {
        '@type': 'ItemList',
        itemListElement: posts.map((p, i) => ({
          '@type': 'ListItem',
          position: i + 1,
          name: p.title,
          url: absolute(origin, routes.post(cid, p.id, p.title)),
        })),
      },
    },
    breadcrumbList(origin, [{ name: c.name, path: routes.community(cid) }]),
  ];
}

export function siteGraph(name: string, origin: string): Thing[] {
  return [
    { '@type': 'WebSite', name, url: absolute(origin, routes.home) },
    breadcrumbList(origin, [{ name, path: routes.home }]),
  ];
}

export function jsonLdText(graph: readonly object[]): string {
  return JSON.stringify({ '@context': 'https://schema.org', '@graph': graph })
    .replaceAll('<', '\\u003c')
    .replaceAll(' ', '\\u2028')
    .replaceAll(' ', '\\u2029');
}

export function useStructuredData(
  build: (state: AppState, origin: string) => readonly object[] | null,
): string | null {
  const origin = useOrigin();

  return useAppState((state) => {
    const graph = build(state, origin);

    return graph?.length ? jsonLdText(graph) : null;
  });
}
