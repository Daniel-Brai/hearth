// @vitest-environment node
import { beforeEach, describe, expect, it } from 'vitest';
import { Store } from '@/data/store';
import { TITLE_MAX } from '@/domain/catalog';
import { canDo } from '@/domain/selectors';
import { MockGateway } from './gateway';
import { createSeedState } from './seed';

let store: Store;
let gateway: MockGateway;

beforeEach(() => {
  store = new Store(createSeedState());
  gateway = new MockGateway(store);
});

describe('settings', () => {
  it('keeps captions off where the instance does not transcribe', () => {
    store.set((state) => {
      state.instance.transcription = false;
    });

    gateway.settings.update({ captions: true });

    expect(store.get().settings.captions).toBe(false);
  });

  it('turns captions on where the instance transcribes', () => {
    gateway.settings.update({ captions: true });

    expect(store.get().settings.captions).toBe(true);
  });
});

describe('posts', () => {
  it('refuses a post in a community the person has not joined', async () => {
    const r = await gateway.posts.create({ c: 'tauri', kind: 'Question', title: 'Hi', body: '' });

    expect(r.ok).toBe(false);
  });

  it('refuses a title longer than the server takes', async () => {
    const title = 'a'.repeat(TITLE_MAX + 1);
    const r = await gateway.posts.create({ c: 'elixir', kind: 'Question', title, body: '' });

    expect(r.ok).toBe(false);
  });

  it('creates a post with its tags and clears the draft', async () => {
    gateway.posts.saveDraft('elixir', { title: 't', body: 'b', kind: 'Question' });

    const r = await gateway.posts.create({
      c: 'elixir',
      kind: 'Question',
      title: 'Help with #morphing',
      body: 'Also #stimulus',
    });

    if (!r.ok) throw new Error(r.error);

    expect(r.value.post.tags).toEqual(['morphing', 'stimulus']);
    expect(store.get().drafts.elixir).toBeUndefined();
    expect(store.get().posts[0]?.id).toBe(r.value.post.id);
  });

  it('lets only the author or a moderator mark the answer', async () => {
    expect((await gateway.posts.toggleAnswer('p1', 'r1')).ok).toBe(false);
    expect((await gateway.posts.toggleAnswer('p8', 'r9')).ok).toBe(true);
    expect(store.get().posts.find((p) => p.id === 'p8')?.answer).toBe('r9');
  });
});

describe('moderation', () => {
  const reply = { kind: 'Reply' as const, id: 'r1', who: 'kai', where: 'x', text: 'y' };

  it('refuses a report where the community is not moderated', async () => {
    const off = await gateway.moderation.report({ ...reply, c: 'runclub', reason: 'spam' });

    expect(off.ok).toBe(false);
  });

  it('refuses the same person reporting the same thing twice', async () => {
    await gateway.moderation.report({ ...reply, c: 'elixir', reason: 'spam' });
    const again = await gateway.moderation.report({ ...reply, c: 'elixir', reason: 'hate' });

    expect(again.ok).toBe(false);
  });

  it('queues a report wherever reports are allowed, screening or not', async () => {
    store.set((state) => (state.instance.aiScreening = false));

    const queued = await gateway.moderation.report({ ...reply, c: 'elixir', reason: 'spam' });

    expect(queued.ok && queued.value.queued).toBe(true);
    expect(store.get().queue[0]?.reports?.[0]?.reason).toBe('spam');
  });

  it('refuses removing without a reason', async () => {
    const r = await gateway.moderation.removeContent({ c: 'elixir', kind: 'Reply', id: 'r1' }, ' ');

    expect(r.ok).toBe(false);
  });

  it('removes and restores someone else’s reply, logging both', async () => {
    const ref = { c: 'plang', kind: 'Reply' as const, id: 'r9' };

    await gateway.moderation.removeContent(ref, 'Spam');

    const removed = store
      .get()
      .posts.flatMap((p) => p.replies)
      .find((r) => r.id === 'r9');

    expect(removed?.moderated).toBe(true);

    await gateway.moderation.restoreContent(ref);

    const back = store
      .get()
      .posts.flatMap((p) => p.replies)
      .find((r) => r.id === 'r9');

    expect(back?.removed).toBe(false);
    expect(store.get().modlog[0]?.action).toBe('restored');
  });

  it('bans by username once, logging the reason', async () => {
    const first = await gateway.moderation.ban({
      c: 'plang',
      username: '@kaivendor',
      reason: 'Spam',
      until: 'permanent',
    });

    const again = await gateway.moderation.ban({
      c: 'plang',
      username: 'kaivendor',
      reason: 'Spam',
      until: 'permanent',
    });

    expect(first.ok).toBe(true);
    expect(again.ok).toBe(false);
    expect(store.get().modlog[0]?.action).toBe('banned');
  });
});

describe('chat commands', () => {
  it('runs /play only where the room allows sounds', () => {
    const allowed = gateway.chat.send('elixir/general', '/play tada');
    const refused = gateway.chat.send('elixir/help', '/play tada');

    expect(allowed.ok && allowed.value.sound).toBe('tada');
    expect(refused.ok).toBe(false);
  });

  it('turns picked messages into a post that remembers the room', async () => {
    const r = await gateway.chat.promote('elixir/help', ['m1', 'm3', 'm5'], {
      title: 'Stimulus state after a refresh',
      kind: 'Question',
    });

    if (!r.ok) throw new Error(r.error);

    expect(r.value.post.fromChat).toEqual({ room: 'help', count: 3 });
    expect(r.value.post.replies).toHaveLength(2);
  });
});

describe('communities', () => {
  it('builds a community from a template with its rooms, roles and first event', async () => {
    const r = await gateway.communities.create({
      name: 'Plant Parents',
      tagline: 'Leaves',
      hue: 'green',
      audience: 'indexed',
      logo: null,
      template: 'club',
    });

    if (!r.ok) throw new Error(r.error);

    const slug = r.value.community;

    if (!slug) throw new Error('No community');

    const state = store.get();

    expect(state.communities[slug]?.rooms.map((x) => x.id)).toEqual(['general', 'show-and-tell']);

    expect(state.roles.filter((x) => x.c === slug).map((x) => x.id)).toEqual([
      'owner',
      'moderator',
      'member',
    ]);

    expect(state.events.some((e) => e.c === slug)).toBe(true);
  });
});

describe('permissions', () => {
  it('sends each joined community a list of permission strings and none to others', () => {
    const state = store.get();

    expect(state.communities.elixir?.permissions).toContain('post.create');
    expect(state.communities.tauri?.permissions).toEqual([]);
  });

  it('updates the list when a role changes, and checks only read that list', async () => {
    expect(canDo(store.get(), 'elixir', 'post.create')).toBe(true);

    for (const role of store.get().roles.filter((r) => r.c === 'elixir' && !r.locked)) {
      await gateway.roles.setPermission('elixir', role.id, 'post.create', false);
    }

    expect(store.get().communities.elixir?.permissions).not.toContain('post.create');
    expect(canDo(store.get(), 'elixir', 'post.create')).toBe(false);
  });
});

describe('rooms', () => {
  it('archives a room and brings it back', async () => {
    expect((await gateway.rooms.archive('plang', 'general')).ok).toBe(true);
    expect(store.get().communities.plang?.rooms.some((r) => r.id === 'general')).toBe(false);
    expect(store.get().archivedRooms.plang?.[0]).toMatchObject({ id: 'general', type: 'text' });

    expect((await gateway.rooms.restore('plang', 'general')).ok).toBe(true);
    expect(store.get().communities.plang?.rooms.some((r) => r.id === 'general')).toBe(true);
    expect(store.get().archivedRooms.plang).toEqual([]);
  });
});
