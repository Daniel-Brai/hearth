import { useEffect, useMemo, useRef, useState } from 'react';
import { Badge, cn, Emoji, Icon, IconButton } from '@/design-system';
import { useFullscreen } from '@/design-system/components/video-fullscreen';
import { pipSupported, popOutShare } from '@/runtime/share-pip';
import { useVoiceStream } from '@/runtime/voice-streams';
import { useUi } from '@/runtime/ui-store';
import { usePageKeys } from '@/shell/key-actions';
import { PersonAvatar, PersonName } from '@/shell/people';
import type { ChatToggle } from './LiveRoomControls';
import { FloatZone } from './LiveRoomStage';
import { QUICK_REACTIONS } from './share-view';
import { VoiceChat } from './VoiceChat';
import { screenStream } from './voice-media';
import type { RoomSession } from './voice-session';

type Talker = { readonly id: string; readonly speaking: boolean };

type ShareTileProps = {
  readonly by: string;
  readonly focus: boolean;
  readonly floats: RoomSession['floats'];
  readonly talkers: readonly Talker[];
  readonly onToggleFocus: () => void;
  readonly onReact: (emoji: string) => void;
  readonly mine?: boolean | undefined;
  readonly chat: ChatToggle;
  readonly room: { readonly cid: string; readonly rid: string; readonly name: string };
};

export function ShareTile({
  by,
  mine,
  focus,
  floats,
  talkers,
  onToggleFocus,
  onReact,
  chat,
  room,
}: ShareTileProps) {
  const box = useRef<HTMLDivElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const remote = useVoiceStream('remoteScreen');
  // Your own share shows what you're capturing, as the others see it arrive
  const stream = mine ? screenStream() : remote;
  const screen = useFullscreen(box, video);

  useEffect(() => {
    if (video.current && video.current.srcObject !== stream) video.current.srcObject = stream;
  }, [stream]);

  const setShareFull = useUi((u) => u.setShareFull);

  useEffect(() => {
    setShareFull(screen.on);
    return () => setShareFull(false);
  }, [screen.on, setShareFull]);

  const keys = useMemo(() => ({ voice_share_fullscreen: screen.toggle }), [screen.toggle]);

  usePageKeys(keys);

  // Real full screen leaves on Esc by itself, the window-filling fallback doesn't
  const { expanded, leave } = screen;

  useEffect(() => {
    if (!expanded) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') leave();
    };

    document.addEventListener('keydown', onKey);

    return () => document.removeEventListener('keydown', onKey);
  }, [expanded, leave]);

  return (
    <section
      ref={box}
      id="voice-share"
      className={cn(
        'share-tile',
        screen.on && 'is-full',
        screen.expanded && 'share-tile--expanded',
      )}
      aria-label="Shared screen"
      data-layout={focus ? 'focus' : 'grid'}
    >
      {stream ? (
        <video
          ref={video}
          autoPlay
          muted
          playsInline
          onClick={onToggleFocus}
          onDoubleClick={screen.toggle}
        />
      ) : (
        <p className="share-tile__note">The shared screen shows here in a moment.</p>
      )}

      <span className="share-tile__label">
        <Icon name="screen" />
        {mine ? (
          <span>You're sharing your screen</span>
        ) : (
          <span>
            <PersonName id={by} /> is sharing their screen
          </span>
        )}
      </span>

      {screen.on && talkers.length > 0 ? <TalkerRow talkers={talkers} /> : null}

      <FloatZone floats={floats} over />

      {screen.on && chat.open ? (
        <VoiceChat cid={room.cid} rid={room.rid} name={room.name} onClose={chat.toggle} />
      ) : null}

      <ShareControls
        chat={chat}
        focus={focus}
        full={screen.on}
        onToggleFocus={onToggleFocus}
        onToggleFull={screen.toggle}
        onReact={onReact}
      />
    </section>
  );
}

// Whoever is talking comes first, and past a few the rest are a count like elsewhere
const TALKERS_SHOWN = 4;

function TalkerRow({ talkers }: { readonly talkers: ShareTileProps['talkers'] }) {
  const ordered = [...talkers].sort((a, b) => Number(b.speaking) - Number(a.speaking));
  const shown = ordered.slice(0, TALKERS_SHOWN);
  const extra = ordered.length - shown.length;

  return (
    <div className="share-tile__talkers" aria-label="On stage">
      {shown.map((t) => (
        <span
          key={t.id}
          className={cn('speaker speaker--mini', t.speaking && 'is-speaking')}
          data-speaking={t.speaking || undefined}
        >
          <PersonAvatar id={t.id} size="sm" />
        </span>
      ))}
      {extra > 0 ? (
        <span className="share-tile__more" aria-label={`and ${extra} more`}>
          +{extra}
        </span>
      ) : null}
    </div>
  );
}

function ShareControls({
  chat,
  focus,
  full,
  onToggleFocus,
  onToggleFull,
  onReact,
}: {
  readonly chat: ChatToggle;
  readonly focus: boolean;
  readonly full: boolean;
  readonly onToggleFocus: () => void;
  readonly onToggleFull: () => void;
  readonly onReact: (emoji: string) => void;
}) {
  const [canPip] = useState(pipSupported);

  return (
    <div className="share-tile__bar">
      <div className="share-tile__reactions" role="group" aria-label="React">
        {QUICK_REACTIONS.map((emoji) => (
          <button
            key={emoji}
            type="button"
            className="share-tile__react"
            onClick={() => onReact(emoji)}
            aria-label={`React ${emoji.slice(1, -1)}`}
          >
            <Emoji value={emoji} />
          </button>
        ))}
      </div>

      <div className="share-tile__tools">
        <IconButton
          id="voice-share-chat"
          variant="quiet"
          className="has-badge"
          on={chat.open}
          onClick={chat.toggle}
          aria-pressed={chat.open}
          aria-label={chat.unread ? 'Chat, new messages' : 'Chat'}
          data-tip="Chat"
        >
          <Icon name="chat" />
          {chat.unread ? <Badge red corner className="voice-chat-dot" aria-hidden="true" /> : null}
        </IconButton>
        {full ? null : (
          <IconButton
            id="voice-share-focus"
            variant="quiet"
            onClick={onToggleFocus}
            aria-label={focus ? 'Show everyone' : 'Focus on the screen'}
            data-tip={focus ? 'Show everyone' : 'Focus on the screen'}
          >
            <Icon name={focus ? 'grid' : 'expand'} />
          </IconButton>
        )}
        {canPip ? (
          <IconButton
            id="voice-share-pip"
            variant="quiet"
            onClick={() => void popOutShare()}
            aria-label="Picture in picture"
            data-tip="Keep watching in a small window"
          >
            <Icon name="pip" />
          </IconButton>
        ) : null}
        <IconButton
          id="voice-share-fullscreen"
          variant="quiet"
          onClick={onToggleFull}
          aria-label={full ? 'Leave full screen' : 'Full screen'}
          data-tip={full ? 'Leave full screen (F)' : 'Full screen (F)'}
        >
          <Icon name={full ? 'shrink' : 'expand'} />
        </IconButton>
      </div>
    </div>
  );
}
