import { useGateway } from '@/app/gateway-context';
import { shareImage } from '@/app/share-image';
import { indexable, postGraph, useStructuredData } from '@/app/structured-data';
import type { HearthGateway } from '@/data/gateway';
import { useAppState } from '@/data/store';
import { Icon, IconButton, Menu, MenuItem } from '@/design-system';
import { postHref } from '@/domain/selectors';
import { attachmentSrc, type Post } from '@/domain/types';
import { plainText } from '@/features/markdown/plain-text';
import { shareUrl } from '@/features/share/share-links';
import { openShareSheet } from '@/features/share/share-sheet';
import { ShareButton } from '@/features/share/ShareButton';
import { useShareable } from '@/features/share/use-shareable';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { useGuest } from '@/shell/use-guest';

import { usePostActions } from './use-post-actions';
import type { PostViewData } from './use-post-view';

function firstImage(post: Post): string | null {
  const image = post.files?.find((f) => f.kind === 'image');

  return image ? attachmentSrc(image) : null;
}

export function PostHeaderBar({
  post,
  view,
  onEdit,
}: {
  readonly post: Post;
  readonly view: PostViewData;
  readonly onEdit: () => void;
}) {
  const { viewer } = useGuest();
  const indexed = useAppState((state) => indexable(state, post.c));
  const jsonLd = useStructuredData((state, origin) => postGraph(state, post.id, origin));

  return (
    <PageHeader
      label={post.title.length > 40 ? post.title.slice(0, 38).trim() + '…' : post.title}
      title={view.communityName}
      documentTitle={[post.title, view.communityName]}
      description={plainText(post.body).slice(0, 200) || null}
      image={shareImage(`/og/posts/${post.id}`, firstImage(post) ?? view.communityImage)}
      noindex={!indexed}
      jsonLd={jsonLd}
      endActions={
        <>
          <ShareButton
            id="post-share"
            className="hide-mobile"
            cid={post.c}
            path={postHref(post)}
            title={post.title}
            text={plainText(post.body).slice(0, 160) || null}
            label="Share post"
          />
          {viewer === 'member' ? <SaveButton post={post} /> : null}
          {viewer === 'member' ? <WatchButton post={post} /> : null}
          {viewer === 'unknown' ? <span className="skel skel--avatar" aria-hidden="true" /> : null}
          <PostMenu post={post} view={view} onEdit={onEdit} />
        </>
      }
    />
  );
}

async function toggleWatch(gateway: HearthGateway, flash: (text: string) => void, post: Post) {
  const watching = post.watching;
  const r = await gateway.posts.toggleWatch(post.id);
  flash(r.ok ? (watching ? 'Stopped watching' : 'Watching. You will get new replies.') : r.error);
}

async function toggleSave(gateway: HearthGateway, flash: (text: string) => void, post: Post) {
  const saved = post.bookmarked;
  const r = await gateway.posts.toggleSave(post.id);
  flash(r.ok ? (saved ? 'Removed from Saved' : 'Saved. Find it under Saved.') : r.error);
}

function sharePost(post: Post, flash: (text: string) => void) {
  const url = shareUrl(postHref(post), window.location.origin);
  const copy = () =>
    void navigator.clipboard.writeText(url).then(
      () => flash('Link copied'),
      () => flash('Copy the address from the bar'),
    );

  void openShareSheet(
    { url, title: post.title, text: plainText(post.body).slice(0, 160) || null },
    copy,
  );
}

function WatchButton({ post }: { readonly post: Post }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  return (
    <IconButton
      on={post.watching}
      className="hide-mobile"
      onClick={() => void toggleWatch(gateway, flash, post)}
      aria-pressed={post.watching}
      aria-label={post.watching ? 'Stop watching' : 'Watch this post'}
      data-tip="Watch"
    >
      <Icon name="eye" />
    </IconButton>
  );
}

function SaveButton({ post }: { readonly post: Post }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  return (
    <IconButton
      id="post-save"
      on={post.bookmarked}
      className="hide-mobile"
      onClick={() => void toggleSave(gateway, flash, post)}
      aria-pressed={post.bookmarked}
      aria-label={post.bookmarked ? 'Remove from Saved' : 'Save for later'}
      data-tip={post.bookmarked ? 'Saved' : 'Save'}
    >
      <Icon name="bookmark" />
    </IconButton>
  );
}

function useMenuItems(post: Post, view: PostViewData) {
  const { viewer } = useGuest();
  const shareable = useShareable(post.c);

  return menuItems(post, view, viewer === 'member', shareable);
}

function menuItems(post: Post, view: PostViewData, member: boolean, shareable: boolean) {
  const mine = post.author === view.me;

  const items = {
    mine,
    copyLink: !shareable,
    share: shareable,
    watch: member,
    edit: mine && !post.removed,
    reportable: !mine && view.reports && member && !post.removed,
    removable: (mine || view.mod) && !post.removed,
    lockable: view.mod && !post.removed,
    restorable: view.mod && !!post.moderated,
    bannable: !mine && view.canBan,
  };

  const always = [
    items.copyLink,
    items.edit,
    view.canPin,
    items.lockable,
    items.reportable,
    items.removable,
    items.restorable,
    items.bannable,
  ].some(Boolean);

  return { ...items, always, empty: !always && !items.share && !items.watch };
}

function PostMenu({
  post,
  view,
  onEdit,
}: {
  readonly post: Post;
  readonly view: PostViewData;
  readonly onEdit: () => void;
}) {
  const flash = useUi((s) => s.flash);
  const { togglePin, toggleLock, report, remove, restore, ban } = usePostActions(post, view);
  const items = useMenuItems(post, view);
  const { mine, copyLink, share, watch, edit, reportable, removable, bannable } = items;

  if (items.empty) return null;

  return (
    <Menu
      trigger={({ toggle, open }) => (
        <IconButton
          className={items.always ? undefined : 'mobile-only'}
          onClick={toggle}
          aria-expanded={open}
          aria-label="Post options"
        >
          <Icon name="dots" />
        </IconButton>
      )}
    >
      <PhoneItems post={post} share={share} watch={watch} />
      {copyLink ? (
        <MenuItem
          icon="link"
          onSelect={() =>
            void navigator.clipboard.writeText(window.location.href).then(
              () => flash('Link copied'),
              () => flash('Copy the address from the bar'),
            )
          }
        >
          Copy link
        </MenuItem>
      ) : null}
      {edit ? (
        <MenuItem icon="pencil" onSelect={onEdit}>
          Edit
        </MenuItem>
      ) : null}
      {view.canPin ? (
        <MenuItem icon="pin" onSelect={togglePin}>
          {post.pinned ? 'Unpin' : 'Pin to the top'}
        </MenuItem>
      ) : null}
      {items.lockable ? (
        <MenuItem icon="lock" onSelect={toggleLock}>
          {post.locked ? 'Unlock replies' : 'Lock replies'}
        </MenuItem>
      ) : null}
      {reportable ? (
        <MenuItem icon="flag" onSelect={report}>
          Report
        </MenuItem>
      ) : null}
      {removable ? (
        <MenuItem icon="trash" danger onSelect={remove}>
          {mine ? 'Delete post' : 'Remove post'}
        </MenuItem>
      ) : null}
      {items.restorable ? (
        <MenuItem icon="refresh" onSelect={restore}>
          Put back
        </MenuItem>
      ) : null}
      {bannable ? (
        <MenuItem icon="shield" danger onSelect={ban}>
          Ban {view.authorShort}
        </MenuItem>
      ) : null}
    </Menu>
  );
}

function PhoneItems({
  post,
  share,
  watch,
}: {
  readonly post: Post;
  readonly share: boolean;
  readonly watch: boolean;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  return (
    <>
      {share ? (
        <MenuItem icon="share" className="mobile-only" onSelect={() => sharePost(post, flash)}>
          Share
        </MenuItem>
      ) : null}
      {watch ? (
        <MenuItem
          icon="bookmark"
          className="mobile-only"
          onSelect={() => void toggleSave(gateway, flash, post)}
        >
          {post.bookmarked ? 'Remove from Saved' : 'Save'}
        </MenuItem>
      ) : null}
      {watch ? (
        <MenuItem
          icon="eye"
          className="mobile-only"
          onSelect={() => void toggleWatch(gateway, flash, post)}
        >
          {post.watching ? 'Stop watching' : 'Watch'}
        </MenuItem>
      ) : null}
    </>
  );
}
