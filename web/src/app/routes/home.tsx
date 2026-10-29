import { HomePage } from '@/pages/home/HomePage';
import { PublicHomePage } from '@/pages/home/PublicHomePage';
import { PageMeta } from '@/shell/PageMeta';
import { RouteSkeleton } from '@/shell/RouteSkeleton';
import { SessionSwitch } from '@/shell/SessionSwitch';

export default function Home() {
  return (
    <SessionSwitch
      signedIn={<HomePage />}
      guest={<PublicHomePage />}
      unknown={
        <>
          <PageMeta title={['Catch up']} noindex />
          <RouteSkeleton />
        </>
      }
    />
  );
}
