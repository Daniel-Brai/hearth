import { useLocation, useParams } from 'react-router';
import { idFromSegment } from '@/runtime/routes';
import type { KeyScope } from '@/runtime/keys';

export type RouteContext = {
  readonly community: string | null;
  readonly room: string | null;
  readonly postId: string | null;
  readonly isHome: boolean;
  readonly scope: KeyScope;
};

const SCOPE_BY_SEGMENT: Record<string, KeyScope> = { voice: 'voice', chat: 'chat' };

export function useRouteContext(): RouteContext {
  const params = useParams();
  const { pathname } = useLocation();

  const community = params.community ?? null;
  const postId = idFromSegment(params.post);
  const segment = pathname.split('/')[3];

  let scope: KeyScope = 'global';

  if (postId) scope = 'post';
  else if (segment && SCOPE_BY_SEGMENT[segment]) scope = SCOPE_BY_SEGMENT[segment];
  else if (community) scope = 'community';

  return { community, room: params.room ?? null, postId, isHome: pathname === '/', scope };
}
