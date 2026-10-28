import { HomePage } from '@/pages/home/HomePage';
import { PublicHomePage } from '@/pages/home/PublicHomePage';
import { SessionSwitch } from '@/shell/SessionSwitch';

export default function Home() {
  return <SessionSwitch signedIn={<HomePage />} guest={<PublicHomePage />} />;
}
