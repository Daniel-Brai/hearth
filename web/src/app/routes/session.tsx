import { ErrorPage } from '@/pages/errors/ErrorPage';
import { SessionShell } from '@/shell/SessionShell';

export function ErrorBoundary() {
  return <ErrorPage code={500} />;
}

export default SessionShell;
