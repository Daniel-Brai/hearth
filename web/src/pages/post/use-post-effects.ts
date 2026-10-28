import { useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { useGuest } from '@/shell/use-guest';
import { usePageKeys } from '@/shell/key-actions';
import { useFlashFailure } from '@/runtime/use-flash-failure';

export function usePostEffects(id: string) {
  const gateway = useGateway();
  const [search] = useSearchParams();
  const { guest, signIn } = useGuest();
  const settle = useFlashFailure();

  useEffect(() => {
    if (!guest) void gateway.posts.markSeen(id);
  }, [gateway, id, guest]);

  useEffect(() => {
    if (search.get('reply')) document.getElementById('reply-box')?.focus();
  }, [search]);

  const keys = useMemo(
    () => ({
      post_helpful: guest ? signIn : () => settle(gateway.posts.toggleHelpful(id)),
      post_reply: guest ? signIn : () => document.getElementById('reply-box')?.focus(),
    }),
    [gateway, id, guest, signIn, settle],
  );

  usePageKeys(keys);
}
