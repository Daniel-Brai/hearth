import { useEffect } from 'react';
import { create } from 'zustand';

type Handler = () => void;

type KeyActionsState = {
  handlers: Record<string, Handler>;
  register: (handlers: Record<string, Handler>) => () => void;
};

export const useKeyActions = create<KeyActionsState>((set) => ({
  handlers: {},

  register: (handlers) => {
    set((s) => ({ handlers: { ...s.handlers, ...handlers } }));

    return () =>
      set((s) => {
        const next = { ...s.handlers };
        Object.keys(handlers).forEach((k) => delete next[k]);
        return { handlers: next };
      });
  },
}));

export function usePageKeys(handlers: Record<string, Handler>) {
  const register = useKeyActions((s) => s.register);

  useEffect(() => register(handlers), [register, handlers]);
}
