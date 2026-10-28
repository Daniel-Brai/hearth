import { Badge, Icon, Link, Measure, Panel, SettingsRow } from '@/design-system';
import { useAppState } from '@/data/store';
import { isInstanceAdmin, pendingRequests } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { CreationSelect } from '@/pages/settings/CreationSelect';
import { ScreeningPanel } from '@/pages/settings/ScreeningPanel';
import { UpdatesPanel } from '@/pages/settings/UpdatesPanel';

export function InstanceSettingsPage() {
  const admin = useAppState((state) => isInstanceAdmin(state));
  const waiting = useAppState((state) => pendingRequests(state).length);

  const reported = useAppState(
    (state) => state.queue.filter((x) => x.c === 'dm' && x.status === 'pending').length,
  );

  if (!admin) return <ErrorPage code={403} forbidden="admins" />;

  return (
    <>
      <PageHeader label="instance settings" eyebrow="Instance" title="Instance settings" />

      <main id="main">
        <Measure narrow className="grid gap-4">
          <Panel className="grid" id="instance-creation">
            <SettingsRow
              title="Who can start communities"
              sub="With By request, people ask and you decide."
            >
              <CreationSelect id="instance-creation-select" />
            </SettingsRow>

            <Link
              className="settings-row settings-link"
              id="instance-requests-link"
              to={routes.requests}
            >
              <span>
                <strong className="small">Community requests</strong>
                <span className="x-small subtle">
                  {waiting ? waiting + ' waiting for you' : 'Nothing waiting'}
                </span>
              </span>
              <span className="flex items-center gap-2">
                {waiting ? <Badge red count={waiting} /> : null}
                <span style={{ display: 'inline-grid', rotate: '-90deg' }}>
                  <Icon name="chevron" />
                </span>
              </span>
            </Link>

            <Link
              className="settings-row settings-link"
              id="instance-reports-link"
              to={routes.instanceReports}
            >
              <span>
                <strong className="small">Reported messages</strong>
                <span className="x-small subtle">
                  {reported ? reported + ' waiting for you' : 'Direct messages people reported'}
                </span>
              </span>
              <span className="flex items-center gap-2">
                {reported ? <Badge red count={reported} /> : null}
                <span style={{ display: 'inline-grid', rotate: '-90deg' }}>
                  <Icon name="chevron" />
                </span>
              </span>
            </Link>
          </Panel>

          <ScreeningPanel />

          <UpdatesPanel />
        </Measure>
      </main>
    </>
  );
}
