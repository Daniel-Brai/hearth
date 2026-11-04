import { useNavigate } from 'react-router';

import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { ScheduledNote, type ScheduledWords } from '@/features/schedule/ScheduledNote';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';

const WORDS: ScheduledWords = {
  noun: 'post',
  goes: 'Posts',
  now: 'Post now',
  sentNow: 'Posted',
  deleted: 'Scheduled post deleted',
};

export function ScheduledPosts({ cid }: { readonly cid: string }) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const ask = useUi((s) => s.ask);
  const items = useAppState((state) => state.scheduledPosts.filter((p) => p.c === cid));
  const hasDraft = useAppState((state) => !!state.drafts[cid]);

  // Editing takes it off the schedule and back into the draft, where it can be posted or scheduled again
  const edit = (id: string) => {
    const item = items.find((p) => p.id === id);

    if (!item) return;

    const take = async () => {
      await gateway.posts.saveDraft(cid, { title: item.title, body: item.body, kind: item.kind });
      gateway.posts.unschedule(id);
      void navigate(routes.communityNew(cid));
    };

    if (!hasDraft && !item.files.length) {
      void take();
      return;
    }

    ask({
      title: 'Edit this post?',
      body: [
        hasDraft ? 'It replaces the draft you have in this community.' : null,
        item.files.length ? "Drafts don't keep files, so add them again before it goes out." : null,
      ]
        .filter(Boolean)
        .join(' '),
      action: 'Edit',
      onConfirm: () => void take(),
    });
  };

  return (
    <ScheduledNote
      id="scheduled-posts"
      entries={items.map((p) => ({
        id: p.id,
        sendAt: p.sendAt,
        title: p.title,
        text: p.body,
        files: p.files.length,
        failure: p.failure,
      }))}
      words={WORDS}
      actions={{
        sendNow: gateway.posts.publishNow,
        reschedule: (id, at) => gateway.posts.reschedule(id, at.toISOString()),
        edit,
        remove: gateway.posts.unschedule,
      }}
    />
  );
}
