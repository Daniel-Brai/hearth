import type { AppState } from '@/domain/app-state';
import { community, displayName } from '@/domain/selectors';
import type { Message, PostKind } from '@/domain/types';
import { onlineFirst, peopleIndex } from '@/pages/people/people-select';

export type ChatTarget = {
  readonly key: string;
  readonly cid: string | null;
  readonly room: string | null;
  readonly dm: string | null;
};

export type ChatContext = {
  readonly target: ChatTarget;
  readonly title: string;
  readonly me: string | null;
  readonly mod: boolean;
  readonly promote: boolean;
  readonly reports: boolean;
  readonly previews: boolean;
  readonly selectMode: boolean;
  readonly picked: readonly string[];
  readonly activeId: string | null;
  readonly editingId: string | null;
  readonly setActive: (id: string | null) => void;
  readonly togglePick: (id: string) => void;
  readonly startSelect: (id: string) => void;
  readonly startEdit: (id: string) => void;
  readonly stopEdit: () => void;
  readonly replyingId: string | null;
  readonly repliedTo: ReadonlySet<string>;
  readonly replyTo: (m: Message) => void;
};

export type ChatThread = {
  readonly message: Message;
  readonly day: string | null;
  readonly grouped: boolean;
  readonly replies: readonly Message[];
};

export function chatThreads(list: readonly Message[]): ChatThread[] {
  const byId = new Map(list.map((m) => [m.id, m]));

  /** A reply whose thread hasn't loaded has no root yet, so it waits for that thread instead of showing alone */
  const rootOf = (m: Message): string | null => {
    let current = m;
    const seen = new Set([m.id]);

    while (current.parent) {
      const parent = byId.get(current.parent);

      if (!parent) return null;
      if (seen.has(parent.id)) break;

      seen.add(parent.id);
      current = parent;
    }

    return current.id;
  };

  const repliesOf = new Map<string, Message[]>();
  const heads: { message: Message; day: string | null }[] = [];
  let pendingDay: string | null = null;

  for (const m of list) {
    if (m.day) pendingDay = m.day;

    const root = rootOf(m);

    if (root === null) continue;

    if (root !== m.id) {
      const replies = repliesOf.get(root);

      if (replies) replies.push(m);
      else repliesOf.set(root, [m]);

      continue;
    }

    heads.push({ message: m, day: pendingDay });
    pendingDay = null;
  }

  return heads.map(({ message, day }, i) => {
    const before = heads[i - 1]?.message;
    const grouped =
      !!before &&
      !day &&
      before.who === message.who &&
      !before.system &&
      !message.system &&
      !repliesOf.has(before.id);

    return { message, day, grouped, replies: repliesOf.get(message.id) ?? [] };
  });
}

export function roomTitle(state: AppState, target: ChatTarget): string {
  if (target.dm) return displayName(state, target.dm);

  const c = community(state, target.cid);
  const voice = c?.voice.find((v) => v.id === target.room);

  if (voice) return voice.name;

  const name = c?.rooms.find((r) => r.id === target.room)?.name ?? target.room;

  return name ? '#' + name : 'Chat';
}

export function communityPeople(state: AppState, cid: string): string[] {
  const ids = new Set<string>();

  if (state.me) ids.add(state.me);

  peopleIndex(state).forEach((cids, id) => {
    if (cids.includes(cid)) ids.add(id);
  });

  return [...ids];
}

export function roomMembers(state: AppState, target: ChatTarget): string[] {
  if (!target.cid) return [];

  const ids = new Set(communityPeople(state, target.cid));

  (state.chats[target.key] ?? []).forEach((m) => {
    if (state.people[m.who]) ids.add(m.who);
  });

  return [...ids].sort(onlineFirst(state));
}

export function promoteKind(kinds: readonly PostKind[], text: string): string {
  const answers = kinds.find((k) => k.answers);
  const talk = kinds.find((k) => !k.answers);

  return (text.includes('?') ? answers : talk)?.name ?? kinds[0]?.name ?? 'Discussion';
}

export const LEVELS = ['none', 'reports', 'full'] as const;
