import { useState } from 'react';
import { useNavigate } from 'react-router';
import {
  Badge,
  Button,
  ChoiceTiles,
  Icon,
  Link,
  Measure,
  Panel,
  Select,
  SettingsRow,
  Switch,
  type Option,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { handle, isInstanceAdmin, pendingRequests, person } from '@/domain/selectors';
import type { DigestChoice, ThemePreference } from '@/domain/types';
import { feel, setHapticsEnabled } from '@/runtime/haptics';
import { CUES, playTune, setSoundsEnabled, sfx, type CueName } from '@/runtime/sounds';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { CreationSelect } from '@/pages/settings/CreationSelect';
import { EmailDialog } from './EmailDialog';
import { PushRow } from './PushRow';
import './SettingsPage.css';

const DIGEST_OPTIONS: readonly Option<DigestChoice>[] = [
  { value: 'daily', label: 'Every morning' },
  { value: 'weekly', label: 'Mondays' },
  { value: 'never', label: 'Never' },
];

const THEMES = [
  { value: 'light', icon: 'sun', label: 'Light' },
  { value: 'dark', icon: 'moon', label: 'Dark' },
  { value: 'system', icon: 'monitor', label: 'Match system' },
] as const;

const isCue = (name: string): name is CueName => name in CUES;

const CUE_LIST = Object.entries(CUES).flatMap(([id, cue]) =>
  isCue(id) ? [{ id, label: cue.label }] : [],
);

export function SettingsPage() {
  const gateway = useGateway();
  const navigate = useNavigate();
  const openDialog = useUi((s) => s.openDialog);

  const view = useAppState((state) => ({
    me: state.me,
    email: state.me ? (state.people[state.me]?.email ?? null) : null,
    handle: state.me ? handle(state, state.me) : null,
    username: state.me ? person(state, state.me).username : null,
    theme: state.settings.theme,
    compact: state.settings.compact,
    changedKeys: Object.keys(state.settings.keys).length,
    notifyReplies: state.settings.notifyReplies,
    notifyMentions: state.settings.notifyMentions,
    notifyLive: state.settings.notifyLive,
    digest: state.settings.digest,
    admin: isInstanceAdmin(state),
    waiting: pendingRequests(state).length,
  }));

  const [changingEmail, setChangingEmail] = useState(false);

  const update = gateway.settings.update;

  const replayTour = () => {
    update({ tourDone: false });
    void navigate(routes.home);
  };

  const signOut = () => {
    gateway.session.signOut();
    void navigate(routes.signIn);
  };

  return (
    <>
      <PageHeader
        label="settings"
        title="Settings"
        actions={
          view.username ? (
            <Link
              to={routes.profile(view.username)}
              className="btn btn--circle btn--small"
              aria-label="Your profile"
              data-tip="Profile"
            >
              <Icon name="user" />
            </Link>
          ) : null
        }
      />

      <main id="main">
        <Measure narrow className="grid gap-4">
          <Link
            className="panel settings-link"
            id="settings-profile-link"
            to={routes.settingsProfile}
          >
            <span>
              <strong className="small">Profile and privacy</strong>
              <span className="x-small subtle">
                Your name, photo, bio and links, and who sees your name, photo and online status.
              </span>
            </span>
            <span style={{ display: 'inline-grid', rotate: '-90deg' }}>
              <Icon name="chevron" />
            </span>
          </Link>

          {view.email ? (
            <Panel className="grid" id="settings-account">
              <h2 className="section-title" style={{ marginBlockEnd: '0.4rem' }}>
                Account
              </h2>

              <SettingsRow title="Email" sub={view.email}>
                <Button id="settings-email" size="small" onClick={() => setChangingEmail(true)}>
                  <Icon name="mail" />
                  Change
                </Button>
              </SettingsRow>
            </Panel>
          ) : null}

          <Panel className="grid gap-3" id="settings-appearance">
            <h2 className="section-title">Appearance</h2>

            <ChoiceTiles<ThemePreference>
              name="theme"
              label="Theme"
              value={view.theme}
              tiles={THEMES}
              onChange={(theme) => update({ theme })}
            />

            <SettingsRow title="Compact feeds" sub="One line per post, no previews">
              <Switch
                label="Compact feeds"
                checked={view.compact}
                onChange={(compact) => update({ compact })}
              />
            </SettingsRow>

            <SettingsRow
              className="kb-only"
              title="Keyboard shortcuts"
              sub={view.changedKeys ? view.changedKeys + ' changed from the defaults' : undefined}
            >
              <Button id="settings-shortcuts" size="small" onClick={() => openDialog('shortcuts')}>
                <Icon name="keyboard" />
                Customize
              </Button>
            </SettingsRow>
          </Panel>

          <Panel className="grid" id="settings-notifications">
            <h2 className="section-title" style={{ marginBlockEnd: '0.4rem' }}>
              Notifications
            </h2>

            <SettingsRow title="Replies to posts you watch" sub="Including posts you wrote">
              <Switch
                label="Replies"
                checked={view.notifyReplies}
                onChange={(notifyReplies) => update({ notifyReplies })}
              />
            </SettingsRow>

            <SettingsRow
              title="Mentions"
              sub={view.handle ? 'When someone writes ' + view.handle : 'When someone mentions you'}
            >
              <Switch
                label="Mentions"
                checked={view.notifyMentions}
                onChange={(notifyMentions) => update({ notifyMentions })}
              />
            </SettingsRow>

            <SettingsRow title="Live rooms" sub="When a room starts in a community you joined">
              <Switch
                label="Live rooms"
                checked={view.notifyLive}
                onChange={(notifyLive) => update({ notifyLive })}
              />
            </SettingsRow>

            <PushRow />

            <SettingsRow title="Catch up email" sub="A short summary of what you missed">
              <Select
                label="Catch up email"
                value={view.digest}
                options={DIGEST_OPTIONS}
                onChange={(digest) => update({ digest })}
              />
            </SettingsRow>
          </Panel>

          <SoundSettings />

          {view.admin ? (
            <Panel className="grid" id="instance">
              <h2 className="section-title" style={{ marginBlockEnd: '0.4rem' }}>
                Instance
              </h2>

              <SettingsRow
                title="Who can start communities"
                sub="With By request, people ask and you decide."
              >
                <CreationSelect />
              </SettingsRow>

              <Link
                className="settings-row settings-link"
                id="settings-requests-link"
                to={routes.requests}
              >
                <span>
                  <strong className="small">Community requests</strong>
                  <span className="x-small subtle">
                    {view.waiting ? view.waiting + ' waiting for you' : 'Nothing waiting'}
                  </span>
                </span>
                <span className="flex items-center gap-2">
                  {view.waiting ? <Badge red count={view.waiting} /> : null}
                  <span style={{ display: 'inline-grid', rotate: '-90deg' }}>
                    <Icon name="chevron" />
                  </span>
                </span>
              </Link>
            </Panel>
          ) : null}

          <Panel className="grid" id="settings-help">
            <h2 className="section-title" style={{ marginBlockEnd: '0.4rem' }}>
              Help
            </h2>

            <SettingsRow
              title="Take the tour"
              sub="A one minute look around, the same one new members get"
            >
              <Button size="small" onClick={replayTour}>
                <Icon name="map" />
                Start
              </Button>
            </SettingsRow>
          </Panel>

          <Panel className="grid" id="settings-account">
            <h2 className="section-title" style={{ marginBlockEnd: '0.4rem' }}>
              Account
            </h2>

            <SettingsRow
              title="Sign out"
              sub={view.handle ? 'You are signed in as ' + view.handle : undefined}
            >
              <Button id="settings-sign-out" size="small" onClick={signOut}>
                <Icon name="leave" />
                Sign out
              </Button>
            </SettingsRow>
          </Panel>
        </Measure>
      </main>

      {changingEmail ? <EmailDialog onClose={() => setChangingEmail(false)} /> : null}
    </>
  );
}

function SoundSettings() {
  const gateway = useGateway();
  const update = gateway.settings.update;

  const view = useAppState((state) => ({
    uiSounds: state.settings.uiSounds,
    sounds: state.settings.sounds,
    haptics: state.settings.haptics,
  }));

  const setHaptics = (on: boolean) => {
    update({ haptics: on });

    if (on) {
      setHapticsEnabled(true);
      feel('success');
    }
  };

  const setUiSounds = (on: boolean) => {
    update({ uiSounds: on });

    if (on) {
      setSoundsEnabled(true);
      sfx('join');
    }
  };

  return (
    <Panel className="grid" id="settings-sounds">
      <h2 className="section-title" style={{ marginBlockEnd: '0.4rem' }}>
        Sounds and haptics
      </h2>

      <SettingsRow
        title="Interface sounds"
        sub="Short cues when something happens: a toast, a question, a new message or notification, and changes in voice rooms"
      >
        <Switch label="Interface sounds" checked={view.uiSounds} onChange={setUiSounds} />
      </SettingsRow>

      <details className="sound-list">
        <summary className="small">Listen to each sound</summary>

        <div className="sound-list__grid">
          {CUE_LIST.map((cue) => (
            <Button
              key={cue.id}
              size="tiny"
              className="sound-list__btn"
              onClick={() => sfx(cue.id)}
            >
              <Icon name="volume" />
              <span>{cue.label}</span>
            </Button>
          ))}
        </div>
      </details>

      <SettingsRow
        title="Play sounds"
        sub={
          <>
            When someone uses <code>/play</code> in a room that allows it
          </>
        }
      >
        <div className="flex items-center gap-2">
          <Button size="tiny" onClick={() => playTune('tada')}>
            <Icon name="music" />
            Test
          </Button>
          <Switch
            label="Play sounds"
            checked={view.sounds}
            onChange={(sounds) => update({ sounds })}
          />
        </div>
      </SettingsRow>

      <SettingsRow
        title="Haptics"
        sub="A light buzz on your phone when you join or start a room, mute, react, or something goes wrong"
      >
        <Switch label="Haptics" checked={view.haptics} onChange={setHaptics} />
      </SettingsRow>
    </Panel>
  );
}
