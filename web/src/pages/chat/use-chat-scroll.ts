import { useEffect, useEffectEvent, useRef, useState } from 'react';
import type { Message } from '@/domain/types';
import { useGateway } from '@/app/gateway-context';

export function useChatScroll(messages: readonly Message[], roomKey: string) {
  const gateway = useGateway();
  const scroller = useRef<HTMLDivElement>(null);
  const [atBottom, setAtBottom] = useState(true);
  const [anchor, setAnchor] = useState(0);

  const missed = atBottom ? 0 : Math.max(0, messages.length - anchor);

  const scrollToLatest = (smooth: boolean) =>
    scroller.current?.scrollTo({
      top: scroller.current.scrollHeight,
      behavior: smooth ? 'smooth' : 'auto',
    });

  useEffect(() => {
    gateway.chat.open(roomKey);
  }, [gateway, roomKey]);

  const stayAtBottom = useEffectEvent(() => {
    if (atBottom) scrollToLatest(false);
  });

  // react-doctor-disable-next-line react-doctor/no-event-handler -- new messages arrive from the server, not from an event here, so the effect is what keeps the view pinned
  useEffect(() => {
    stayAtBottom();
  }, [messages.length]);

  const onScroll = () => {
    const el = scroller.current;

    if (!el) return;

    const bottom = el.scrollHeight - el.scrollTop - el.clientHeight < 80;

    if (bottom === atBottom) return;

    setAtBottom(bottom);
    setAnchor(messages.length);
  };

  return { scroller, atBottom, setAtBottom, missed, scrollToLatest, onScroll };
}
