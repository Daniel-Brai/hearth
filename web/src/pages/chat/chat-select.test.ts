// @vitest-environment node
import { describe, expect, it } from 'vitest';
import type { Message } from '@/domain/types';
import { chatThreads } from './chat-select';

const message = (id: string, parent: string | null = null): Message => ({
  id,
  who: 'ada',
  text: id,
  time: '9:00 AM',
  boosts: [],
  parent,
});

describe('chatThreads', () => {
  it('holds back a reply whose thread has not loaded', () => {
    const threads = chatThreads([message('root'), message('late', 'unloaded')]);

    expect(threads.map((t) => t.message.id)).toEqual(['root']);
  });

  it('puts a reply under its thread once the thread is there', () => {
    const list = [message('root'), message('answer', 'root'), message('late', 'answer')];

    const [thread] = chatThreads(list);

    expect(thread?.replies.map((m) => m.id)).toEqual(['answer', 'late']);
  });
});
