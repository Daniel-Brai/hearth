import { matchPath, useLocation } from 'react-router';
import { Skeleton, type SkeletonKind } from '@/design-system';
import { patterns, routes } from '@/runtime/routes';

const SHAPES: readonly [string, SkeletonKind][] = [
  [patterns.chat, 'chat'],
  [patterns.dm, 'chat'],
  [patterns.voice, 'chat'],
  [patterns.post, 'post'],
  [patterns.communityNew, 'compose'],
  [routes.newPost, 'compose'],
  [patterns.profile, 'profile'],
  [patterns.moderation, 'queue'],
];

export function RouteSkeleton() {
  const { pathname } = useLocation();
  const kind = SHAPES.find(([pattern]) => matchPath(pattern, pathname))?.[1] ?? 'feed';

  return (
    <main id="main">
      <div className="measure">
        <Skeleton kind={kind} />
      </div>
    </main>
  );
}
