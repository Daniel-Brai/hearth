import { Button, ButtonLink, Measure, Panel } from '@/design-system';
import { useAppState } from '@/data/store';
import { canRequestCommunity, canStartCommunity } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { LeaveDialog } from '@/pages/compose/LeaveDialog';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { ChosenTemplate } from './ChosenTemplate';
import { CommunityFields } from './CommunityFields';
import { LogoField } from './LogoField';
import { TemplatePicker } from './TemplatePicker';
import { useCreateCommunity } from './use-create-community';
import './NewCommunityPage.css';

export function NewCommunityPage() {
  const allowed = useAppState((state) => canStartCommunity(state) || canRequestCommunity(state));

  if (!allowed) return <ErrorPage code={403} forbidden="creators" />;

  return <NewCommunityForm />;
}

function NewCommunityForm() {
  const create = useCreateCommunity();
  const { asRequest, template, form, busy, shake, set } = create;
  const title = asRequest ? 'Request a community' : 'Start a community';

  return (
    <>
      <PageHeader label="new community" title={title} />

      <main id="main">
        {!template ? (
          <Measure narrow className="grid gap-4">
            <p className="subtle small text-center">
              Pick a starting point. It sets up post kinds, rooms and a first event, and you can
              change all of it later.
            </p>

            <TemplatePicker onPick={create.pickTemplate} />
          </Measure>
        ) : (
          <form
            id="new-community-form"
            noValidate
            onSubmit={(e) => {
              e.preventDefault();
              void create.submit();
            }}
          >
            <Measure narrow className="grid gap-4">
              {asRequest ? (
                <p className="subtle small text-center">
                  The instance admin reviews requests. Once it's approved you'll be its Owner.
                </p>
              ) : null}

              <ChosenTemplate template={template} onChange={create.clearTemplate} />

              <Panel className="grid gap-4">
                <LogoField
                  form={form}
                  onPick={create.pickLogo}
                  onRemove={() => set('logo', null)}
                />

                <CommunityFields
                  form={form}
                  template={template}
                  asRequest={asRequest}
                  shake={shake}
                  set={set}
                />
              </Panel>

              <div className="new-community__bar">
                <ButtonLink to={routes.home}>Cancel</ButtonLink>
                <Button type="submit" variant="reversed" busy={busy}>
                  {asRequest ? 'Send request' : 'Create community'}
                </Button>
              </div>
            </Measure>
          </form>
        )}
      </main>

      <LeaveDialog
        blocker={create.blocker}
        title="Leave without creating it?"
        text="What you've filled in for this community will be lost."
        stay="Keep going"
        leave="Discard"
      />
    </>
  );
}
