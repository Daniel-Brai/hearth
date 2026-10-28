import { emptyState } from '@/data/empty-state';
import type { AppState } from '@/domain/app-state';
import type { Permission } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { SEED } from './seed-data';
import { tourDoneRemembered } from './tour-memory';
import { grantPermissions } from './permissions';

const clone = <T>(o: T): T => structuredClone(o);

export const DEFAULT_PERMISSIONS: Record<'member' | 'moderator', Permission[]> = {
  member: ['post.create', 'reply.create', 'message.create', 'invite.create'],
  moderator: [
    'post.create',
    'reply.create',
    'message.create',
    'voice-session.create',
    'voice-session.speak',
    'voice-recording.create',
    'event.create',
    'post.pin',
    'post.answer',
    'chat.promote',
    'content.remove',
    'invite.create',
    'invite.update',
    'room.update',
  ],
};

function ensureRoles(state: AppState) {
  state.roles.forEach((r) => {
    if (!r.c) r.c = 'elixir';
    const invites = !(r.c === 'elixir' && r.id === 'member');
    if (invites && !r.permissions.includes('invite.create')) r.permissions.push('invite.create');
  });

  const base = (id: 'member' | 'moderator') =>
    state.roles.find((r) => r.c === 'elixir' && r.id === id)?.permissions ??
    DEFAULT_PERMISSIONS[id];

  Object.entries(state.communities).forEach(([cid, c]) => {
    if (state.roles.some((r) => r.c === cid)) return;
    state.roles.push(
      {
        c: cid,
        id: 'owner',
        name: 'Owner',
        hue: 'yellow',
        members: [c.maintainer].filter(Boolean),
        locked: true,
        permissions: [],
      },
      {
        c: cid,
        id: 'moderator',
        name: 'Moderator',
        hue: 'green',
        members: [],
        permissions: [...base('moderator')],
      },
      {
        c: cid,
        id: 'member',
        name: 'Member',
        hue: 'ink',
        members: [],
        permissions: [...new Set([...base('member'), 'invite.create' as const])],
      },
    );
  });
}

function resolveHrefs(state: AppState) {
  const toRoute = (href: string) => {
    const [file, qs] = href.split('?');
    const q = new URLSearchParams(qs);

    if (file === 'post.html') {
      const p = state.posts.find((x) => x.id === q.get('id'));
      return p ? routes.post(p.c, p.id, p.title) : routes.home;
    }

    const c = q.get('c');
    const r = q.get('r');

    if (file === 'voice.html' && c && r) return routes.voice(c, r);
    if (file === 'chat.html' && c) return routes.chat(c, r ?? 'general');

    if (file === 'moderation.html') {
      const cid = c ?? Object.keys(state.communities).find((k) => state.communities[k]!.joined);
      return cid ? routes.moderation(cid) : routes.home;
    }

    if (file === 'community.html' && c) return routes.community(c);

    return routes.home;
  };
  state.notifications.forEach((n) => {
    if (n.href.includes('.html')) n.href = toRoute(n.href);
  });
}

type Loose = Record<string, unknown>;

function blankToNull(state: AppState) {
  const nullify = (o: Loose, keys: string[]) =>
    keys.forEach((k) => {
      if (o[k] === '') o[k] = null;
    });

  Object.values(state.people).forEach((p) => {
    nullify(p as Loose, ['bio', 'location', 'pronouns', 'joined']);
    p.links?.forEach((l) => nullify(l as Loose, ['label']));
  });

  Object.values(state.communities).forEach((c) => {
    nullify(c as Loose, ['intro', 'summary', 'place']);
    c.voice.forEach((v) => nullify(v as Loose, ['topic']));
  });

  Object.values(state.roomSettings).forEach((r) => nullify(r as Loose, ['topic']));
  state.modlog.forEach((l) => nullify(l as Loose, ['reason']));
  state.communityRequests.forEach((r) => nullify(r as Loose, ['note']));
  state.events.forEach((e) => nullify(e as Loose, ['desc']));
}

export function createSeedState(overrides: Partial<AppState> = {}): AppState {
  // Fields the seed file leaves out keep the empty defaults
  const state = { ...emptyState(), ...(clone(SEED) as unknown as Partial<AppState>) };

  ensureRoles(state);
  resolveHrefs(state);

  Object.values(state.communities).forEach((c) => {
    if (!c.letter) c.letter = c.name[0]!.toUpperCase();
  });

  blankToNull(state);
  grantPermissions(state);
  if (tourDoneRemembered()) state.settings.tourDone = true;

  return { ...state, ...overrides };
}
