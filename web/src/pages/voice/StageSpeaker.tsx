import { Button, cn, Icon, Link, Menu, MenuItem } from '@/design-system';
import { useAppState } from '@/data/store';
import { person } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { PersonAvatar, PersonName } from '@/shell/people';

type StageSpeakerProps = {
  readonly id: string;
  readonly you?: boolean | undefined;
  readonly host: boolean;
  readonly muted: boolean;
  readonly locked: boolean;
  readonly speaking: boolean;
  readonly sharing: boolean;
  readonly canManage: boolean;
  readonly openRoom: boolean;
  readonly onServerMute: () => void;
  readonly onDemote: () => void;
  readonly onDisconnect: () => void;
};

export function StageSpeaker({
  id,
  you,
  host,
  muted,
  locked,
  speaking,
  sharing,
  canManage,
  openRoom,
  onServerMute,
  onDemote,
  onDisconnect,
}: StageSpeakerProps) {
  const username = useAppState((state) => person(state, id).username);

  return (
    <div
      id={'speaker-' + id}
      className={cn('speaker', speaking && 'is-speaking')}
      data-speaking={speaking || undefined}
    >
      <PersonAvatar id={id} online="auto" />

      <SpeakerBadges muted={muted} locked={locked} sharing={sharing} host={host} />

      <span className="speaker__name truncate">
        {you ? 'You' : <PersonName id={id} />}
        {speaking ? <span className="sr-only">, speaking</span> : null}
      </span>

      {/* Stays up the whole time you're muted, so it never flickers */}
      {you && muted ? (
        <span id="voice-muted-hint" className="speaker__hint" role="status">
          You're muted
        </span>
      ) : null}

      {canManage ? (
        <Menu
          trigger={({ open, toggle, id: menuId }) => (
            <Button
              size="tiny"
              variant="quiet"
              onClick={toggle}
              aria-expanded={open}
              aria-controls={menuId}
            >
              Manage
              <Icon name="chevron" />
            </Button>
          )}
        >
          <MenuItem icon={locked ? 'mic' : 'micoff'} onSelect={onServerMute}>
            {locked ? 'Let them unmute' : 'Mute their mic'}
          </MenuItem>
          {openRoom ? null : (
            <MenuItem icon="volume" onSelect={onDemote}>
              Move to listeners
            </MenuItem>
          )}
          <MenuItem icon="leave" danger onSelect={onDisconnect}>
            Disconnect
          </MenuItem>
          <Link className="popup__item" to={routes.profile(username)}>
            <Icon name="user" />
            View profile
          </Link>
        </Menu>
      ) : null}
    </div>
  );
}

function SpeakerBadges({
  muted,
  locked,
  sharing,
  host,
}: {
  readonly muted: boolean;
  readonly locked: boolean;
  readonly sharing: boolean;
  readonly host: boolean;
}) {
  return (
    <div className="speaker__badges">
      {muted ? (
        <span
          className={cn('mini-badge', locked && 'is-locked')}
          title={locked ? 'Muted by a host' : 'Muted'}
        >
          🔇
        </span>
      ) : null}
      {sharing ? (
        <span className="mini-badge" title="Sharing screen">
          🖥
        </span>
      ) : null}
      {host ? (
        <span className="mini-badge" title="Host">
          ★
        </span>
      ) : null}
    </div>
  );
}
