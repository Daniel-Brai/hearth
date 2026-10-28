import type { ReactNode } from 'react';
import { Avatar, Link, type AvatarSize } from '@/design-system';
import { displayName, initials, person, photoOf, presence } from '@/domain/selectors';
import { useAppState } from '@/data/store';
import { routes } from '@/runtime/routes';

type PersonAvatarProps = {
  readonly id: string;
  readonly size?: AvatarSize | undefined;
  readonly online?: boolean | 'auto' | undefined;
  readonly unread?: boolean | undefined;
  readonly link?: boolean | undefined;
  readonly className?: string | undefined;
};

export function PersonAvatar({ id, size, online, unread, link, className }: PersonAvatarProps) {
  const view = useAppState((state) => ({
    hue: person(state, id).hue,
    initials: initials(state, id),
    photo: photoOf(state, id),
    online: online === 'auto' ? !!presence(state, id)?.online : !!online,
    name: displayName(state, id),
    username: person(state, id).username,
  }));

  const avatar = (
    <Avatar
      hue={view.hue}
      initials={view.initials}
      photo={view.photo}
      size={size}
      online={view.online}

      unread={unread}
      className={className}
    />
  );

  if (!link) return avatar;

  return (
    <Link to={routes.profile(view.username)} aria-label={view.name}>
      {avatar}
    </Link>
  );
}

export function PersonName({ id, short }: { readonly id: string; readonly short?: boolean }) {
  const name = useAppState((state) =>
    short ? displayName(state, id).split(' ')[0] : displayName(state, id),
  );

  return <>{name}</>;
}

export function PersonLink({
  id,
  className,
  labelled,
  children,
}: {
  readonly id: string;
  readonly className?: string | undefined;
  readonly labelled?: boolean | undefined;
  readonly children?: ReactNode;
}) {
  const view = useAppState((state) => ({
    name: displayName(state, id),
    username: person(state, id).username,
  }));

  return (
    <Link
      to={routes.profile(view.username)}
      className={className}
      aria-label={labelled ? view.name : undefined}
    >
      {children ?? view.name}
    </Link>
  );
}
