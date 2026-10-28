import type { Notification, NotificationKind } from '@/domain/types';
import type { Notification as ApiNotification } from '@/generated/schemas';
import { routes } from '@/runtime/routes';
import { ageOf } from './mappers';

type Data = Record<string, unknown>;

const text = (data: Data, key: string): string => {
  const value = data[key];
  return typeof value === 'string' ? value : '';
};

const KINDS = {
  reply: 'reply',
  mention: 'mention',
  answer: 'answer',
  event_scheduled: 'event_scheduled',
  event_reminder: 'event_reminder',
  live_started: 'live',
  transcript_ready: 'transcript',
  invite: 'invite',
  report: 'mod',
} as const satisfies Partial<Record<ApiNotification['kind'], NotificationKind>>;

type Shown = Pick<Notification, 'text' | 'target' | 'href'>;

function shownAs(kind: keyof typeof KINDS, data: Data): Shown {
  const community = text(data, 'community_slug');
  const post = routes.post(community, text(data, 'post_id'), text(data, 'post_title'));

  switch (kind) {
    case 'reply':
      return { text: 'replied to you', target: text(data, 'post_title'), href: post };
    case 'answer':
      return {
        text: 'marked your reply as the answer',
        target: text(data, 'post_title'),
        href: post,
      };
    case 'mention':
      return {
        text: 'mentioned you in ' + text(data, 'community_name'),
        target: text(data, 'post_title') || text(data, 'excerpt'),
        href: text(data, 'url') || routes.community(community),
      };
    case 'event_scheduled':
      return {
        text: 'scheduled ' + text(data, 'event_title'),
        target: text(data, 'community_name'),
        href: routes.event(community, text(data, 'event_id'), text(data, 'event_title')),
      };
    case 'event_reminder':
      return {
        text: `starts in ${String(data['minutes'] ?? '')} minutes`,
        target: text(data, 'event_title'),
        href: routes.event(community, text(data, 'event_id'), text(data, 'event_title')),
      };
    case 'live_started':
      return {
        text: 'went live in ' + (text(data, 'room_name') || text(data, 'community_name')),
        target: text(data, 'topic'),
        href: text(data, 'room_slug')
          ? routes.voice(community, text(data, 'room_slug'))
          : routes.community(community),
      };
    case 'transcript_ready':
      return {
        text: 'The transcript is ready',
        target: text(data, 'event_title'),
        href: routes.session(community, text(data, 'session_id')),
      };
    case 'invite':
      return {
        text: `${text(data, 'inviter_name')} invited you to join`,
        target: text(data, 'community_name'),
        href: routes.join(text(data, 'code')),
      };
    // Who reported something is never named so these come from Hearth itself
    case 'report': {
      const thing = text(data, 'subject_type') || 'post';

      if (!community)
        return {
          text: 'got a report about a direct message',
          target: 'Instance reports',
          href: routes.instanceReports,
        };

      return {
        text:
          data['held'] === true ? `held a ${thing} for review` : `got a report about a ${thing}`,
        target: text(data, 'community_name'),
        href: routes.moderation(community) + '#queue-' + text(data, 'item_id'),
      };
    }
  }
}

const isShown = (kind: ApiNotification['kind']): kind is keyof typeof KINDS => kind in KINDS;

// Direct messages are left out since conversations show them as unread
export function toNotification(notification: ApiNotification): Notification | null {
  if (!isShown(notification.kind)) return null;

  return {
    id: notification.id,
    kind: KINDS[notification.kind],
    who: notification.actor?.id ?? 'hearth',
    ...shownAs(notification.kind, notification.data),
    age: ageOf(notification.inserted_at),
    read: notification.read_at !== null,
  };
}
