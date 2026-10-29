import { useNavigate } from 'react-router';
import { Avatar, Button, ButtonLink, Icon, Link, Pill, type IconName } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { Markdown } from '@/features/markdown/Markdown';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { useGuest } from '@/shell/use-guest';
import { ProfileLinks } from './ProfileLinks';
import type { ProfileViewData } from './use-profile-view';

export function ProfileHead({ id, view }: { readonly id: string; readonly view: ProfileViewData }) {
  return (
    <section className="profile-head">
      <ProfileAvatar view={view} />

      <div className="grid gap-1">
        <h2 className="page-title">{view.name}</h2>
        {view.showName ? (
          <span className="subtle icon-text justify-center">{view.handle}</span>
        ) : null}
        {view.hidden ? (
          <Pill className="justify-self-center">
            <Icon name="eyeoff" />
            <span>{view.mine ? 'Others only see your username' : 'Shows only their username'}</span>
          </Pill>
        ) : null}
      </div>

      {view.bio ? (
        <Markdown className="profile-bio balance" text={view.bio} community={null} />
      ) : (
        <p className="subtle small">
          {view.mine ? 'Add a line about what you work on.' : 'No bio yet.'}
        </p>
      )}

      <ProfileFacts view={view} />

      <ProfileLinks links={view.links} />

      <div className="stat-row my-2.5">
        <Stat value={view.helped} label="People helped" />
        <Stat value={view.posts} label="Posts" />
        <Stat value={view.answers} label="Answers" />
      </div>

      <ProfileActions id={id} view={view} />
    </section>
  );
}

function ProfileAvatar({ view }: { readonly view: ProfileViewData }) {
  if (!view.mine) {
    return <Avatar size="xl" hue={view.hue} initials={view.initials} photo={view.photo} />;
  }

  return (
    <Link
      to={routes.settingsProfile}
      className="inline-grid"
      aria-label="Change your photo"
      data-tip="Change photo"
    >
      <Avatar
        size="xl"
        className="avatar--editable"
        hue={view.hue}
        initials={view.initials}
        photo={view.photo}
      >
        <span className="avatar__badge">
          <Icon name="image" />
        </span>
      </Avatar>
    </Link>
  );
}

function ProfileFacts({ view }: { readonly view: ProfileViewData }) {
  return (
    <div className="profile-facts small subtle">
      {view.presenceLabel ? (
        <span className="icon-text">
          <span
            className={
              view.online
                ? 'presence-dot presence-dot--inline'
                : 'presence-dot presence-dot--inline is-away'
            }
          />
          <span>{view.presenceLabel}</span>
          {view.presenceNote ? <span className="subtle">({view.presenceNote})</span> : null}
        </span>
      ) : null}
      <Fact icon="user" text={view.pronouns} />
      <Fact icon="map" text={view.showName ? view.location : null} />
      <Fact icon="calendar" text={view.joined ? `Joined ${view.joined}` : null} />
    </div>
  );
}

function Fact({ icon, text }: { readonly icon: IconName; readonly text: string | null }) {
  if (!text) return null;

  return (
    <span className="icon-text">
      <Icon name={icon} />
      <span>{text}</span>
    </span>
  );
}

function Stat({ value, label }: { readonly value: number; readonly label: string }) {
  return (
    <div className="stat">
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  );
}

function ProfileActions({ id, view }: { readonly id: string; readonly view: ProfileViewData }) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const { viewer, signIn } = useGuest();

  const message = () => {
    if (viewer === 'guest') {
      signIn();
      return;
    }

    if (viewer === 'unknown') return;

    gateway.chat.openDm(id);
    void navigate(routes.dm(view.username));
  };

  const copyUsername = () => {
    navigator.clipboard.writeText(view.handle).then(
      () => flash(`Copied ${view.handle}`),
      () => flash('Could not copy the username'),
    );
  };

  if (viewer === 'unknown')
    return (
      <div className="flex items-center gap-2 flex-wrap justify-center" aria-hidden="true">
        <span className="skel skel--btn" />
        <span className="skel skel--btn" />
      </div>
    );

  return (
    <div className="flex items-center gap-2 flex-wrap justify-center">
      {view.mine ? (
        <>
          <ButtonLink to={routes.settingsProfile}>
            <Icon name="pencil" />
            Edit profile
          </ButtonLink>
          <ButtonLink to={routes.settings}>
            <Icon name="gear" />
            Settings
          </ButtonLink>
        </>
      ) : (
        <>
          <Button variant="reversed" onClick={message}>
            <Icon name="chat" />
            Message
          </Button>
          <Button onClick={copyUsername}>
            <Icon name="at" />
            Copy username
          </Button>
        </>
      )}
    </div>
  );
}
