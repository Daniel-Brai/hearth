import { Button, EmptyState, Measure } from '@/design-system';
import { PageHeader } from './PageHeader';
import { useGuest } from './use-guest';

export function GuestWall() {
  const { signIn } = useGuest();

  return (
    <>
      <PageHeader label="Invite only" title="Invite only" documentTitle={['Invite only']} />

      <main id="main">
        <Measure className="grid justify-items-center gap-3">
          <EmptyState
            art="lock"
            title="This community is invite only"
            text="You need to be a member to see its posts, events and people. Sign in if you are one, or ask a member for an invite."
          />
          <Button id="guest-wall-sign-in" variant="reversed" onClick={signIn}>
            Sign in
          </Button>
        </Measure>
      </main>
    </>
  );
}
