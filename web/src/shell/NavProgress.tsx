import { useLoading } from '@/data/use-load';

export function NavProgress() {
  const loading = useLoading();

  return <div className={loading ? 'nav-progress is-on' : 'nav-progress'} aria-hidden="true" />;
}
