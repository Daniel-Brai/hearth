import { useNavigate } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { person } from '@/domain/selectors';
import type { Post } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { useModerationActions } from '@/features/moderation/use-moderation-actions';
import { useUi } from '@/runtime/ui-store';
import type { PostViewData } from './use-post-view';

export function usePostActions(post: Post, view: PostViewData) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);
  const id = post.id;
  const mine = post.author === view.me;

  const togglePin = async () => {
    const pinned = post.pinned;
    const r = await gateway.posts.togglePin(id);
    flash(r.ok ? (pinned ? 'Unpinned' : 'Pinned') : r.error);
  };

  const toggleLock = async () => {
    const locked = post.locked;
    const r = await gateway.posts.toggleLock(id);
    flash(r.ok ? (locked ? 'Replies are open again' : 'Locked. Nobody can reply now.') : r.error);
  };

  const moderation = useModerationActions();
  const authorUsername = useAppState((state) => person(state, post.author).username);
  const ref = { c: post.c, kind: 'Post' as const, id };

  const report = () =>
    moderation.report({
      c: post.c,
      kind: 'Post',
      id,
      who: post.author,
      where: 'in ' + view.communityName,
      text: post.title,
    });

  const remove = () =>
    mine
      ? ask({
          title: 'Delete this post?',
          body: 'The post and all of its replies will be removed for everyone.',
          action: 'Delete post',
          onConfirm: () => {
            // The post goes at once so leave first and flash if it fails
            void navigate(routes.community(post.c));
            void gateway.posts.remove(id).then((r) => flash(r.ok ? 'Post deleted' : r.error));
          },
        })
      : moderation.remove(ref);

  const restore = () => moderation.restore(ref);

  const ban = () =>
    ask({
      title: `Ban ${view.authorName} from ${view.communityName}?`,
      body: "They can't post, chat or join rooms there until someone unbans them. The reason shows in the public log.",
      action: 'Ban',
      note: { label: 'Reason', placeholder: 'Which guideline they broke', required: true },
      onConfirm: ({ note }) =>
        void gateway.moderation
          .ban({ c: post.c, username: authorUsername, reason: note, until: 'permanent' })
          .then((r) =>
            flash(r.ok ? `${view.authorName} is banned from ${view.communityName}` : r.error),
          ),
    });

  const startLive = async () => {
    const r = await gateway.posts.startLive(id);

    if (!r.ok) return flash(r.error);
    flash("You're live. People reading the post were asked to join.");
    void navigate(routes.voice(post.c, r.value.room));
  };

  const join = () => {
    const r = gateway.communities.join(post.c);
    if (!r.ok) flash(r.error);
  };

  return { togglePin, toggleLock, report, remove, restore, ban, startLive, join };
}
