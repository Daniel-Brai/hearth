import { AUDIENCE_LABEL } from '@/domain/audience';
import { useState, type CSSProperties } from 'react';
import { useNavigate } from 'react-router';
import {
  Badge,
  Button,
  ButtonLink,
  cn,
  CommunityMark,
  Dot,
  Icon,
  Link,
  LiveDot,
  Menu,
  MenuItem,
} from '@/design-system';
import { fmt, plural } from '@/domain/format';
import { linkIcon, linkText } from '@/domain/links';
import { Markdown } from '@/features/markdown/Markdown';
import { routes } from '@/runtime/routes';
import { PersonAvatar } from '@/shell/people';
import type { CommunityViewData } from './use-community-view';

type HeroProps = {
  readonly cid: string;
  readonly view: CommunityViewData;
  readonly onToggleJoin: () => void;
};

export function CommunityHero({ cid, view, onToggleJoin }: HeroProps) {
  return (
    <section className="community-hero">
      <div
        className={cn('community-hero__banner', !view.banner && 'is-default')}
        style={
          view.banner
            ? { backgroundImage: `url('${view.banner}')` }
            : ({ '--tint': `var(--hue-${view.hue})` } as CSSProperties)
        }
      />

      <div className="community-hero__body">
        <div className="community-hero__top">
          <CommunityMark
            hue={view.hue}
            letter={view.letter}
            logo={view.logo}
            size="4.6rem"
            className="community-mark--hero"
          />

          <HeroActions cid={cid} view={view} onToggleJoin={onToggleJoin} />
        </div>

        {/* The header above already names the community */}
        {view.tagline ? <p className="community-hero__title subtle">{view.tagline}</p> : null}

        <HeroMeta view={view} />

        {view.intro ? <Intro text={view.intro} cid={cid} /> : null}

        {view.links.length ? (
          <div className="chips">
            {view.links.map((l) => (
              <a key={l.url} className="chip" href={l.url} target="_blank" rel="noopener">
                <Icon name={linkIcon(l.url)} />
                <span>{linkText(l)}</span>
              </a>
            ))}
          </div>
        ) : null}

        {view.live.map((v) => (
          <LiveRoomLink key={v.id} cid={cid} room={v} />
        ))}
      </div>
    </section>
  );
}

function HeroActions({ cid, view, onToggleJoin }: HeroProps) {
  return (
    <div className="community-hero__actions">
      {view.canEdit || view.mod ? (
        <ManageMenu cid={cid} view={view} />
      ) : view.canInvite ? (
        <ButtonLink size="small" to={routes.invite(cid)}>
          <Icon name="invite" />
          Invite
        </ButtonLink>
      ) : null}
      {view.locked ? null : (
        <Button size="small" variant={view.joined ? 'default' : 'reversed'} onClick={onToggleJoin}>
          {view.joined ? <Icon name="check" /> : null}
          <span>{view.joined ? 'Joined' : 'Join'}</span>
        </Button>
      )}
    </div>
  );
}

function ManageMenu({ cid, view }: { readonly cid: string; readonly view: CommunityViewData }) {
  const navigate = useNavigate();

  return (
    <Menu
      left
      trigger={({ open, toggle, id }) => (
        <Button
          size="small"
          className="community-hero__manage"
          onClick={toggle}
          aria-expanded={open}
          aria-haspopup="menu"
          aria-controls={open ? id : undefined}
        >
          <Icon name="gear" />
          Manage
          {view.queue ? <Badge red count={view.queue} /> : null}
          <Icon name="chevron" />
        </Button>
      )}
    >
      {view.canEdit ? (
        <MenuItem icon="pencil" onSelect={() => navigate(routes.communityEdit(cid))}>
          Edit community
        </MenuItem>
      ) : null}
      {view.mod ? (
        <MenuItem
          icon="shield"
          hint={view.queue ? <Badge red count={view.queue} /> : null}
          onSelect={() => navigate(routes.moderation(cid))}
        >
          Moderation
        </MenuItem>
      ) : null}
      {view.canInvite ? (
        <MenuItem icon="invite" onSelect={() => navigate(routes.invite(cid))}>
          Invite people
        </MenuItem>
      ) : null}
    </Menu>
  );
}

function HeroMeta({ view }: { readonly view: CommunityViewData }) {
  return (
    <div className="community-hero__meta small subtle">
      <span className="tabular">
        <strong>{fmt(view.members)}</strong> members
      </span>
      <span className="icon-text">
        <Dot green />
        <span className="tabular">{view.online} online</span>
      </span>
      <span className="icon-text">
        <Icon name={view.visibility === 'public' ? 'globe' : 'lock'} />
        <span>{AUDIENCE_LABEL[view.audience]}</span>
      </span>
      {view.notModerated ? (
        <span className="icon-text" data-tip="No automatic checks and no reporting">
          <Icon name="shield" />
          <span>Not moderated</span>
        </span>
      ) : null}
      <Link to={routes.profile(view.maintainerUsername)} className="icon-text">
        <PersonAvatar id={view.maintainer} size="xs" />
        <span>Run by {view.maintainerName}</span>
      </Link>
    </div>
  );
}

function LiveRoomLink({
  cid,
  room: v,
}: {
  readonly cid: string;
  readonly room: CommunityViewData['live'][number];
}) {
  return (
    <Link className="origin-note origin-note--live" to={routes.voice(cid, v.id)}>
      <span className="origin-note__text">
        <LiveDot />
        <strong>{v.name}</strong>
        <span className="truncate subtle">{v.topic}</span>
      </span>
      <span className="listen-actions">
        <span
          className="listen-count"
          data-tip={plural(v.listeners, 'person listening', 'people listening')}
          aria-label={v.listeners + ' listening'}
        >
          <Icon name="users" />
          <span>{v.listeners}</span>
        </span>
        <span className="btn btn--tiny">
          <Icon name="volume" />
          <span>{v.mode === 'open' ? 'Join' : 'Listen in'}</span>
        </span>
      </span>
    </Link>
  );
}

function Intro({ text, cid }: { readonly text: string; readonly cid: string }) {
  const long = text.length >= 160 || text.includes('\n');
  const [open, setOpen] = useState(false);

  return (
    <div className={cn('community-hero__intro', (open || !long) && 'is-open')}>
      <Markdown text={text} community={cid} />
      {long ? (
        <Button size="tiny" variant="borderless" onClick={() => setOpen((o) => !o)}>
          {open ? 'Show less' : 'Read more'}
        </Button>
      ) : null}
    </div>
  );
}
