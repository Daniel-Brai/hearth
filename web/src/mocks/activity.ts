import type { AppState } from '@/domain/app-state';
import type { ProfileActivity } from '@/domain/types';

export function profileActivity(state: AppState, id: string): ProfileActivity {
  const readable = (c: string) => {
    const community = state.communities[c];
    return !!community && (community.visibility !== 'invite' || community.joined);
  };
  const shown = state.posts.filter((p) => !p.removed && !p.pending && readable(p.c));

  return {
    posts: shown.filter((p) => p.author === id).map((p) => p.id),
    postsAfter: null,
    replies: shown.flatMap((p) =>
      p.replies
        .filter((r) => r.who === id && !r.removed)
        .map((r) => ({
          id: r.id,
          postId: p.id,
          c: p.c,
          title: p.title,
          excerpt: r.body[0] ?? null,
          helpful: r.helpful,
          age: r.age,
          answer: p.answer === r.id,
        })),
    ),
    repliesAfter: null,
  };
}
