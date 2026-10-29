import { useResponseStatus } from '@/app/request-context';
import { Button, ButtonLink, EmptyState, Icon, type IlloName } from '@/design-system';
import { useAppState } from '@/data/store';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { PageMeta } from '@/shell/PageMeta';

export type ErrorCode = 403 | 404 | 410 | 500 | 'offline';

export type Forbidden =
  | 'private'
  | 'moderators'
  | 'editors'
  | 'creators'
  | 'invites'
  | 'roles'
  | 'rooms'
  | 'events'
  | 'admins';

type Copy = { art: IlloName; title: string; text: string };

const FORBIDDEN: Record<Forbidden, Copy> = {
  private: {
    art: 'lock',
    title: 'This community is private',
    text: 'You need an invite to see it. Ask an admin for a link, or sign in with the account that was invited.',
  },
  moderators: {
    art: 'lock',
    title: 'Only moderators can open this',
    text: "You don't review content in this community. Ask its owner if you think you should.",
  },
  editors: {
    art: 'lock',
    title: "You can't edit this community",
    text: 'Your role here does not include changing how the community looks or works. Ask its owner.',
  },
  creators: {
    art: 'lock',
    title: "You can't start a community here",
    text: 'On this server only its admins start communities. Ask the person who runs it.',
  },
  invites: {
    art: 'lock',
    title: "You can't invite people here",
    text: "Your role in this community doesn't include inviting. Ask its owner or a moderator to send the invite.",
  },
  roles: {
    art: 'lock',
    title: "You can't manage roles here",
    text: 'Your role here does not include changing who can do what. Ask someone who can, such as its owner.',
  },
  rooms: {
    art: 'lock',
    title: "You can't change this room",
    text: 'Your role here does not include changing rooms. Ask a moderator or the owner.',
  },
  events: {
    art: 'lock',
    title: "You can't schedule events here",
    text: 'Your role here does not include scheduling or changing events. Ask a moderator or the owner.',
  },
  admins: {
    art: 'lock',
    title: 'Only instance admins can open this',
    text: 'This manages the whole server. Ask the person who runs it.',
  },
};

const COPY: Record<Exclude<ErrorCode, 403>, Copy> = {
  404: {
    art: 'lost',
    title: "We couldn't find that",
    text: 'The link may be old, or what it pointed to was moved or deleted. Everything else is right where you left it.',
  },
  410: {
    art: 'lost',
    title: 'This post is gone',
    text: 'It was removed by a moderator or deleted by its author.',
  },
  500: {
    art: 'broken',
    title: 'Something broke on our end',
    text: "It's not you. We've been told and we're on it. Try again in a minute.",
  },
  offline: {
    art: 'offline',
    title: "Can't reach the Hearth server",
    text: 'Nothing is answering right now. Check your connection and try again in a moment.',
  },
};

export function ErrorPage({
  code,
  forbidden = 'private',
}: {
  readonly code: ErrorCode;
  readonly forbidden?: Forbidden;
}) {
  const signedIn = useAppState((state) => state.me !== null);
  const openDialog = useUi((s) => s.openDialog);
  const copy = code === 403 ? FORBIDDEN[forbidden] : COPY[code];

  useResponseStatus(typeof code === 'number' ? code : 503);

  return (
    <>
      {signedIn ? <PageHeader title={copy.title} label={copy.title} hideTitle noindex /> : null}
      <main className={signedIn ? 'error-in-app' : 'signin'} id="main">
        {signedIn ? null : <PageMeta title={[copy.title]} noindex />}
        <div className={signedIn ? 'error-page' : 'signin__card error-page'}>
          <span className="error-page__code">{typeof code === 'number' ? code : ''}</span>

          <EmptyState art={copy.art} title={copy.title} text={copy.text} />

          <div className="flex items-center gap-2 flex-wrap justify-center">
            <ButtonLink to={routes.home} variant="reversed">
              <Icon name="inbox" />
              Go to Catch up
            </ButtonLink>

            {code === 'offline' || code === 500 ? (
              <Button variant="borderless" onClick={() => window.location.reload()}>
                <Icon name="refresh" />
                Try again
              </Button>
            ) : (
              <Button onClick={() => openDialog('jump')}>
                <Icon name="search" />
                Search
              </Button>
            )}

            {code === 403 ? (
              <ButtonLink to={routes.signIn} variant="borderless">
                <Icon name="key" />
                Switch account
              </ButtonLink>
            ) : null}
          </div>
        </div>
      </main>
    </>
  );
}
