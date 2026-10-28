import { useState } from 'react';
import type { Message } from '@/domain/types';

export function useChatSelection(messages: readonly Message[]) {
  const [selectMode, setSelectMode] = useState(false);
  const [picked, setPicked] = useState<string[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);

  const pickedIds = new Set(picked);
  const pickedMessages = messages.filter((m) => pickedIds.has(m.id) && !m.system);

  const startSelect = (id: string | null) => {
    setSelectMode(true);
    setPicked(id ? [id] : []);
    setActiveId(null);
  };

  const cancelSelect = () => {
    setSelectMode(false);
    setPicked([]);
  };

  const togglePick = (id: string) =>
    setPicked((list) => (list.includes(id) ? list.filter((x) => x !== id) : [...list, id]));

  return {
    selectMode,
    picked,
    pickedMessages,
    activeId,
    setActiveId,
    startSelect,
    cancelSelect,
    togglePick,
  };
}
