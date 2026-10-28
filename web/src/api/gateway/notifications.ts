import type { HearthGateway } from '@/data/gateway';
import {
  notificationIndex,
  notificationRead,
  notificationReadAll,
} from '@/generated/api/notifications/notifications';
import { toPerson } from '../mappers';
import { toNotification } from '../notifications';
import type { GatewayContext } from './context';
import { call } from './context';

const PAGE = 20;

export function createNotificationsGateway(ctx: GatewayContext) {
  const load = async () => {
    const answer = await call(() => notificationIndex());

    if (answer.status !== 200) return;

    const { data, meta, unread } = answer.data;

    ctx.store.set((state) => {
      for (const n of data) if (n.actor) state.people[n.actor.id] ??= toPerson(n.actor);
      state.notifications = data.flatMap((n) => toNotification(n) ?? []);
      state.notificationsAfter = meta.has_next ? meta.after : null;
      state.notificationsUnreadBeyond = Math.max(0, unread - data.filter((n) => !n.read_at).length);
    });
  };

  const notifications: HearthGateway['notifications'] = {
    open: (id) => {
      ctx.store.set((state) => {
        const direct = id.startsWith('dm-')
          ? state.directs.find((d) => 'dm-' + d.who === id)
          : null;

        if (direct) direct.unread = false;

        const notification = state.notifications.find((n) => n.id === id);

        if (notification) notification.read = true;
      });

      if (!id.startsWith('dm-')) void call(() => notificationRead(id));
    },

    markAllRead: () => {
      ctx.store.set((state) => {
        for (const n of state.notifications) n.read = true;
        for (const d of state.directs) d.unread = false;
        state.notificationsUnreadBeyond = 0;
      });

      void call(() => notificationReadAll());
    },

    loadEarlier: async () => {
      const after = ctx.store.get().notificationsAfter;

      if (!after) return;

      const answer = await call(() => notificationIndex({ after, limit: PAGE }));

      if (answer.status !== 200) return;

      const { data, meta } = answer.data;

      ctx.store.set((state) => {
        for (const n of data) if (n.actor) state.people[n.actor.id] ??= toPerson(n.actor);

        const known = new Set(state.notifications.map((n) => n.id));
        const older = data.flatMap((n) => toNotification(n) ?? []).filter((n) => !known.has(n.id));

        state.notifications.push(...older);
        state.notificationsAfter = meta.has_next ? meta.after : null;
      });
    },
  };

  return { notifications, load };
}
