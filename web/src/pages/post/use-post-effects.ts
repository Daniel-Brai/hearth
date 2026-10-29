import { useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { useGuest } from '@/shell/use-guest';
import { usePageKeys } from '@/shell/key-actions';
import { useFlashFailure } from '@/runtime/use-flash-failure';

const noop = () => undefined;

export function usePostEffects(id: string) {
  const gateway = useGateway();
  const [search] = useSearchParams();
  const { viewer, signIn } = useGuest();
  const settle = useFlashFailure();

  const member = viewer === 'member';
  const prompt = viewer === 'guest' ? signIn : noop;

  useEffect(() => {
    if (viewer === 'member') void gateway.posts.markSeen(id);
  }, [gateway, id, viewer]);

  useEffect(() => {
    if (search.get('reply')) document.getElementById('reply-box')?.focus();
  }, [search]);

  const keys = useMemo(
    () => ({
      post_helpful: member ? () => settle(gateway.posts.toggleHelpful(id)) : prompt,
      post_reply: member ? () => document.getElementById('reply-box')?.focus() : prompt,
    }),
    [gateway, id, member, prompt, settle],
  );

  usePageKeys(keys);
}
