import { useSyncExternalStore } from 'react';

// Streams can't live in a store snapshot
type Streams = {
  remoteScreen: MediaStream | null;
};

let streams: Streams = { remoteScreen: null };
const listeners = new Set<() => void>();

export function setVoiceStream<K extends keyof Streams>(key: K, stream: Streams[K]) {
  if (streams[key] === stream) return;

  streams = { ...streams, [key]: stream };
  listeners.forEach((listener) => listener());
}

export const voiceStream = <K extends keyof Streams>(key: K): Streams[K] => streams[key];

export const subscribeVoiceStreams = (listener: () => void) => {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
};

const subscribe = subscribeVoiceStreams;

export function useVoiceStream<K extends keyof Streams>(key: K): Streams[K] {
  return useSyncExternalStore(
    subscribe,
    () => streams[key],
    () => null,
  );
}
