import { matchPath, useLocation } from 'react-router';

import { cn, Skeleton, type SkeletonKind } from '@/design-system';
import { patterns, routes } from '@/runtime/routes';

type Width = 'wide' | 'narrow' | 'read';

/** Each screen's skeleton and the width its content uses so loading doesn't jump */
const SHAPES: readonly [string, SkeletonKind, Width][] = [
  [routes.home, 'catchup', 'wide'],
  [patterns.chat, 'chat', 'wide'],
  [patterns.dm, 'chat', 'wide'],
  [patterns.roomSettings, 'form', 'narrow'],
  [patterns.voice, 'voice', 'wide'],
  [patterns.session, 'transcript', 'read'],
  [patterns.post, 'post', 'wide'],
  [patterns.communityEvents, 'events', 'wide'],
  [patterns.event, 'events', 'wide'],
  [routes.events, 'events', 'wide'],
  [patterns.eventNew, 'form', 'narrow'],
  [patterns.eventEdit, 'form', 'narrow'],
  [patterns.communityNew, 'compose', 'wide'],
  [routes.newPost, 'compose', 'wide'],
  [routes.newCommunity, 'templates', 'narrow'],
  [patterns.communityEdit, 'form', 'narrow'],
  [patterns.invite, 'form', 'narrow'],
  [patterns.roles, 'roles', 'wide'],
  [patterns.log, 'list', 'wide'],
  [patterns.profile, 'profile', 'wide'],
  [patterns.moderation, 'queue', 'wide'],
  [routes.people, 'list', 'narrow'],
  [routes.saved, 'feed', 'narrow'],
  [routes.search, 'feed', 'narrow'],
  [routes.settings, 'settings', 'narrow'],
  [routes.settingsProfile, 'form', 'narrow'],
  [routes.settingsInstance, 'settings', 'narrow'],
  [routes.instanceReports, 'queue', 'wide'],
  [routes.requests, 'cards', 'narrow'],
  [routes.myInvites, 'cards', 'narrow'],
];

export function RouteSkeleton() {
  const { pathname } = useLocation();
  const [, kind, width] = SHAPES.find(([pattern]) => matchPath(pattern, pathname)) ?? [
    '',
    'feed',
    'wide',
  ];

  return (
    <main id="main">
      <div
        className={cn(
          'measure',
          width === 'narrow' && 'measure--narrow',
          width === 'read' && 'measure--read',
        )}
      >
        <Skeleton kind={kind} />
      </div>
    </main>
  );
}
