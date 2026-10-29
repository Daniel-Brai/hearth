import type { HearthGateway, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { ArchivedRoom, ModerationLevel } from '@/domain/types';
import {
  roomArchive,
  roomArchived,
  roomCreate,
  roomDelete,
  roomRestore,
  roomUpdate,
} from '@/generated/api/communities/communities';
import { messageRead } from '@/generated/api/chat/chat';
import { moderationRoomLevel } from '@/generated/api/moderation/moderation';
import type { Room as ApiRoom } from '@/generated/schemas';
import { slugify } from '@/runtime/routes';
import type { GatewayContext } from './context';
import { NOT_READY, call, errorCode, failed, roomDefaults } from './context';

const READ_AFTER_MS = 1000;

const toArchivedRoom = (room: ApiRoom): ArchivedRoom => ({
  id: room.slug,
  name: room.name,
  type: room.type,
  archivedAt: room.archived_at ?? '',
});

export function createRoomsGateway(
  ctx: GatewayContext,
  loadCommunity: (cid: string) => Promise<Result>,
) {
  const roomId = (cid: string, id: string) => ctx.roomIds.get(`${cid}/${id}`);

  const loadArchived = async (cid: string): Promise<Result> => {
    const communityId = ctx.communityIds.get(cid);

    if (!communityId) return fail(NOT_READY);

    const answer = await call(() => roomArchived(communityId));

    if (answer.status !== 200) return failed(answer);

    for (const room of answer.data) ctx.roomIds.set(`${cid}/${room.slug}`, room.id);
    ctx.store.set((state) => (state.archivedRooms[cid] = answer.data.map(toArchivedRoom)));

    return ok(undefined);
  };

  const change = async (
    cid: string,
    id: string,
    send: (roomId: string) => Promise<{ status: number; data: unknown }>,
    expected: number,
  ): Promise<Result> => {
    const target = roomId(cid, id);

    if (!target) return fail(NOT_READY);

    const answer = await call(() => send(target));

    if (answer.status !== expected) return failed(answer);

    await loadCommunity(cid);
    if (ctx.store.get().archivedRooms[cid]) await loadArchived(cid);

    return ok(undefined);
  };

  const readUpTo = new Map<string, string>();
  const reading = new Map<string, ReturnType<typeof setTimeout>>();

  const setUnread = (cid: string, rid: string, unread: number) =>
    ctx.store.set((state) => {
      const room = state.communities[cid]?.rooms.find((r) => r.id === rid);
      if (room) room.unread = unread;
    });

  const sendRead = (cid: string, rid: string) => {
    const key = `${cid}/${rid}`;

    reading.delete(key);

    const newest = ctx.store.get().chats[key]?.findLast((m) => !m.id.startsWith('pending-'))?.id;

    if (!newest || readUpTo.get(key) === newest) return;

    const unread = ctx.store.get().communities[cid]?.rooms.find((r) => r.id === rid)?.unread ?? 0;

    readUpTo.set(key, newest);
    setUnread(cid, rid, 0);

    void call(() => messageRead(newest)).then((answer) => {
      if (answer.status === 204) return;

      readUpTo.delete(key);
      setUnread(cid, rid, unread);
    });
  };

  const load = { archivedRooms: loadArchived } satisfies Partial<HearthGateway['load']>;

  const rooms: HearthGateway['rooms'] = {
    settings: (key) => ctx.store.get().roomSettings[key] ?? roomDefaults(),

    // The server keeps a room's topic and previews and sounds stay in this browser
    updateSettings: (key, patch) => {
      const before = ctx.store.get().roomSettings[key];

      ctx.store.set((state) => {
        state.roomSettings[key] = { ...(state.roomSettings[key] ?? roomDefaults()), ...patch };
      });

      const target = ctx.roomIds.get(key);

      if (!('topic' in patch) || !target) return;

      void call(() => roomUpdate(target, { topic: patch.topic ?? null })).then((answer) => {
        if (answer.status === 200) return;

        ctx.store.set((state) => {
          if (before) state.roomSettings[key] = before;
          else delete state.roomSettings[key];
        });
      });
    },
    setModeration: async (cid, rid, level) => {
      const key = `${cid}/${rid}`;
      const target = roomId(cid, rid);

      if (!target) return fail(NOT_READY);

      const before = ctx.store.get().roomSettings[key]?.moderation;

      const put = (next: ModerationLevel | undefined) =>
        ctx.store.set((state) => {
          const settings = (state.roomSettings[key] ??= roomDefaults());
          if (next) settings.moderation = next;
          else delete settings.moderation;
        });

      put(level);

      const answer = await call(() => moderationRoomLevel(target, { level }));

      if (answer.status === 200) return ok(undefined);

      put(before);

      if (errorCode(answer) === 'above_community')
        return fail("A room can't be moderated more than its community.");

      if (answer.status === 403) return fail('Only people who manage rooms can change this.');

      return failed(answer);
    },
    // Waits until the room has been open a moment so passing through doesn't count as reading it
    markRead: (cid, rid) => {
      const key = `${cid}/${rid}`;
      clearTimeout(reading.get(key));
      reading.set(
        key,
        setTimeout(() => sendRead(cid, rid), READ_AFTER_MS),
      );
    },

    create: async (cid, spec) => {
      const communityId = ctx.communityIds.get(cid);

      if (!communityId) return fail(NOT_READY);

      const answer = await call(() =>
        roomCreate(communityId, {
          type: spec.type,
          name: spec.type === 'text' ? slugify(spec.name) : spec.name.trim(),
          topic: spec.topic.trim() || null,
          ...(spec.access ? { access: spec.access, role_ids: spec.roleIds ?? [] } : {}),
        }),
      );

      if (answer.status !== 201) return failed(answer);

      await loadCommunity(cid);

      return ok({ id: answer.data.slug });
    },

    // The server keeps a room's address when its name changes so links to it still work
    rename: async (cid, from, to) => {
      const voice = ctx.store.get().communities[cid]?.voice.some((v) => v.id === from) ?? false;
      const name = voice ? to.trim() : slugify(to);
      const r = await change(cid, from, (id) => roomUpdate(id, { name }), 200);

      return r.ok ? ok({ id: from }) : r;
    },

    setAccess: (cid, rid, access, roleIds) =>
      change(cid, rid, (id) => roomUpdate(id, { access, role_ids: roleIds }), 200),

    archive: (cid, id) => change(cid, id, roomArchive, 200),
    restore: (cid, id) => change(cid, id, roomRestore, 200),
    destroy: (cid, id) => change(cid, id, roomDelete, 204),
  };

  return { load, rooms };
}
