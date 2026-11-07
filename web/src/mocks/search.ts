import { coversWords } from '@/domain/search';
import type { Post, SearchHit } from '@/domain/types';
import { plainText } from '@/features/markdown/plain-text';

const EXCERPT = 160;

const excerptOf = (body: readonly string[]) => plainText(body).slice(0, EXCERPT);

/** Finds a post the way the server does through its own text or else one of its replies */
export function mockHit(post: Post, words: readonly string[]): SearchHit | null {
  if (coversWords(post.title + ' ' + post.body.join(' '), words))
    return { id: post.id, reply: null, excerpt: excerptOf(post.body) };

  const reply = post.replies.find((r) => !r.removed && coversWords(r.body.join(' '), words));

  return reply ? { id: post.id, reply: reply.id, excerpt: excerptOf(reply.body) } : null;
}
