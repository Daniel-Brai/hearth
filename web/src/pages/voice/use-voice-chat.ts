import { useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';

export function useVoiceChat(key: string, open: boolean): { readonly unread: boolean } {
  const gateway = useGateway();

  useLoad(() => gateway.load.chat(key), 'chat:' + key);

  const newest = useAppState((state) => {
    const list = state.chats[key];
    if (!list) return undefined;

    return list.findLast((m) => m.who !== state.me && !m.system)?.id ?? null;
  });

  const [seen, setSeen] = useState<string | null | undefined>(undefined);

  if (newest !== undefined && newest !== seen && (open || seen === undefined)) setSeen(newest);

  return { unread: !open && seen !== undefined && newest !== undefined && newest !== seen };
}
