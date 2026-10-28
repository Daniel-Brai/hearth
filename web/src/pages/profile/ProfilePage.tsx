import { useParams } from 'react-router';
import { Measure } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { plural } from '@/domain/format';
import { personIdByHandle } from '@/domain/selectors';
import { plainText } from '@/features/markdown/plain-text';
import { ShareButton } from '@/features/share/ShareButton';
import { routes } from '@/runtime/routes';
import { profileGraph, useStructuredData } from '@/app/structured-data';
import { PageHeader } from '@/shell/PageHeader';
import { shareImage } from '@/app/share-image';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { ProfileActivity } from './ProfileActivity';
import { ProfileCommunities } from './ProfileCommunities';
import { ProfileHead } from './ProfileHead';
import { profileCommunities } from './profile-data';
import { useProfileView } from './use-profile-view';
import './ProfilePage.css';

export function ProfilePage() {
  const { handle } = useParams();

  if (!handle) return <ErrorPage code={404} />;

  return <ProfileLoader handle={handle} />;
}

function ProfileLoader({ handle }: { readonly handle: string }) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.profile(handle), 'profile:' + handle);
  const id = useAppState((state) => personIdByHandle(state, handle));

  if (load.status === 'error' || !id) return <ErrorPage code={404} />;

  return <ProfileView id={id} />;
}

function ProfileView({ id }: { readonly id: string }) {
  const view = useProfileView(id);
  const jsonLd = useStructuredData((state, origin) => profileGraph(state, id, origin));

  const communities = useAppState(
    (state) => profileCommunities(state, id),
    () => false,
  );

  return (
    <>
      <PageHeader
        label={view.mine ? 'your profile' : view.name}
        title="Profile"
        documentTitle={[view.name]}
        description={view.bio ? plainText(view.bio).slice(0, 200) : summaryOf(view)}
        image={shareImage(`/og/users/${encodeURIComponent(view.username)}`, view.photo)}
        jsonLd={jsonLd}
        endActions={
          <ShareButton
            id="profile-share"
            path={routes.profile(view.username)}
            title={view.name}
            text={view.bio ? plainText(view.bio).slice(0, 160) : null}
            label="Share profile"
          />
        }
      />

      <main id="main">
        <Measure className="grid gap-4">
          <ProfileHead id={id} view={view} />

          {communities.length ? <ProfileCommunities view={view} communities={communities} /> : null}

          <ProfileActivity id={id} handle={view.username} mine={view.mine} />
        </Measure>
      </main>
    </>
  );
}

const summaryOf = (view: { name: string; username: string; posts: number; helped: number }) =>
  `${view.name} (@${view.username}) on Hearth. ${plural(view.posts, 'post')}, ${plural(view.helped, 'person', 'people')} helped.`;
