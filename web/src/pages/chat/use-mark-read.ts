import { useEffect } from 'react';
import { useGateway } from '@/app/gateway-context';
import type { Message } from '@/domain/types';
import type { ChatTarget } from './chat-select';

export function useMarkRead(target: ChatTarget, messages: readonly Message[]) {
  const gateway = useGateway();
  const newest = messages.at(-1)?.id ?? null;
  const { cid, room } = target;

  useEffect(() => {
    if (cid && room && newest) gateway.rooms.markRead(cid, room);
  }, [gateway, cid, room, newest]);
}
