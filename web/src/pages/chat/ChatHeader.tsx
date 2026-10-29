import { useNavigate } from 'react-router';
import { ButtonLink, Icon, IconButton, Link, Menu, MenuTitle, useMenu } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import {
  canDo,
  community,
  displayName,
  handle,
  modLevel,
  person,
  presence,
  roomAccess,
  roomSettings,
} from '@/domain/selectors';
import { PrivateLock } from '@/features/rooms/PrivateLock';
import { routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { PersonAvatar } from '@/shell/people';
import { roomMembers, type ChatTarget } from './chat-select';

type ChatHeaderProps = {
  readonly target: ChatTarget;
  readonly title: string;
  readonly selectMode: boolean;
  readonly canPromote: boolean;
  readonly onToggleSelect: () => void;
};

export function ChatHeader({
  target,
  title,
  selectMode,
  canPromote,
  onToggleSelect,
}: ChatHeaderProps) {
  const view = useAppState((state) => {
    const settings = roomSettings(state, target.key);
    const unmoderated = !!target.cid && modLevel(state, target.cid, target.room) === 'none';

    return {
      eyebrow: target.dm ? 'Direct message' : (community(state, target.cid)?.name ?? null),
      sub:
        [settings.topic, unmoderated ? 'Not moderated' : null]
          .filter((s): s is string => !!s)
          .join(' · ') || null,
      canRooms: canDo(state, target.cid, 'room.update'),
      access: roomAccess(state, target.cid, target.room),
      dmUsername: target.dm ? person(state, target.dm).username : null,
      dmName: target.dm ? displayName(state, target.dm) : null,
    };
  });

  return (
    <PageHeader
      ruled
      label={title}
      eyebrow={view.eyebrow}
      title={
        <>
          {title} <PrivateLock room={view} />
        </>
      }
      sub={target.dm ? null : view.sub}
      endActions={
        <>
          {target.dm === null ? <MembersMenu target={target} title={title} /> : null}

          {canPromote ? (
            <IconButton
              on={selectMode}
              onClick={onToggleSelect}
              aria-pressed={selectMode}
              aria-label="Select messages to turn into a post"
              data-tip="Promote to post"
            >
              <Icon name="megaphone" />
            </IconButton>
          ) : null}

          {target.dm && view.dmUsername ? (
            <Link
              to={routes.profile(view.dmUsername)}
              aria-label={`View ${view.dmName}'s profile`}
              data-tip="View profile"
            >
              <PersonAvatar id={target.dm} size="sm" online="auto" />
            </Link>
          ) : null}

          {target.cid && target.room && view.canRooms ? (
            <ButtonLink
              circle
              size="small"
              to={routes.roomSettings(target.cid, target.room)}
              aria-label="Room settings"
              data-tip="Room settings"
            >
              <Icon name="sliders" />
            </ButtonLink>
          ) : null}
        </>
      }
    />
  );
}

function MembersMenu({ target, title }: { readonly target: ChatTarget; readonly title: string }) {
  const members = useAppState((state) => roomMembers(state, target));

  return (
    <Menu
      className="hide-mobile"
      popupClassName="members-popup"
      trigger={({ toggle, open }) => (
        <button
          type="button"
          className="avatar-stack members-btn"
          onClick={toggle}
          aria-expanded={open}
          aria-label={`${members.length} people in this room`}
          data-tip="People in this room"
        >
          {members.slice(0, 3).map((id) => (
            <PersonAvatar key={id} id={id} size="sm" />
          ))}
          {members.length > 3 ? (
            <span className="avatar avatar--sm members-btn__more">+{members.length - 3}</span>
          ) : null}
        </button>
      )}
    >
      <MenuTitle>
        In {title} · {members.length}
      </MenuTitle>

      {members.map((id) => (
        <MemberRow key={id} id={id} />
      ))}
    </Menu>
  );
}

function MemberRow({ id }: { readonly id: string }) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const menu = useMenu();

  const view = useAppState((state) => {
    const name = displayName(state, id);

    return {
      me: state.me === id,
      name,
      username: person(state, id).username,
      sub:
        presence(state, id)?.label ??
        (name === handle(state, id) ? 'Status hidden' : handle(state, id)),
    };
  });

  const message = () => {
    menu?.close();
    gateway.chat.openDm(id);
    void navigate(routes.dm(view.username));
  };

  return (
    <div className="popup__item">
      <Link
        className="flex min-w-0 flex-1 items-center gap-3 text-inherit no-underline"
        to={routes.profile(view.username)}
        onClick={() => menu?.close()}
      >
        <PersonAvatar id={id} size="sm" online="auto" />

        <span className="members-popup__name">
          <strong>{view.name + (view.me ? ' (you)' : '')}</strong>
          <small className="subtle">{view.sub}</small>
        </span>
      </Link>

      {!view.me ? (
        <IconButton
          variant="borderless"
          size="tiny"
          className="members-popup__message"
          onClick={message}
          aria-label={'Message ' + view.name}
          data-tip="Message"
        >
          <Icon name="chat" />
        </IconButton>
      ) : null}
    </div>
  );
}
