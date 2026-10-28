import type { AppState } from '../app-state';
import type { Notification } from '../types';
import { routes } from '@/runtime/routes';
import { person } from './people';

export const dmCount = (d: { unread: number | boolean }) => (d.unread === true ? 1 : d.unread || 0);

const dmNotices = (state: AppState): Notification[] =>
  state.directs
    .filter((d) => dmCount(d))
    .map((d) => ({
      id: 'dm-' + d.who,
      kind: 'dm',
      who: d.who,
      text: 'sent you a message',
      target: 'Open the conversation',
      href: routes.dm(person(state, d.who).username),
      age: d.age || 'now',
      read: false,
      dm: true,
    }));

export const unreadList = (state: AppState) =>
  dmNotices(state).concat(state.notifications.filter((n) => !n.read));

export const unreadNotifications = (state: AppState) =>
  unreadList(state).length + state.notificationsUnreadBeyond;
