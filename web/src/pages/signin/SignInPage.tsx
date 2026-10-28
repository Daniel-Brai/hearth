import { Navigate } from 'react-router';
import { CommunityMark } from '@/design-system';
import { useAppState } from '@/data/store';
import { community } from '@/domain/selectors';
import { AuthLogo } from '@/pages/signin/AuthLogo';
import { PageMeta } from '@/shell/PageMeta';
import { ProfileStep } from './ProfileStep';
import { CodeStep, EmailStep } from './SignInSteps';
import { useSignIn } from './use-sign-in';
import './SignInPage.css';

export function SignInPage() {
  const flow = useSignIn();
  const { invite, step } = flow;

  const inviteCommunity = useAppState((state) => {
    const c = invite ? community(state, invite.c) : null;
    return c ? { name: c.name, hue: c.hue, letter: c.letter, logo: c.logo } : null;
  });

  if (flow.signedInTo) return <Navigate replace to={flow.signedInTo} />;

  return (
    <main className="signin" id="main">
      <PageMeta
        title={['Sign in']}
        description="Sign in or join with an email code. First time here creates your account."
      />
      <div className="signin__card">
        <AuthLogo size="1.6rem" />

        {inviteCommunity ? (
          <span className="invite-banner" id="signin-invite">
            <CommunityMark
              hue={inviteCommunity.hue}
              letter={inviteCommunity.letter}
              logo={inviteCommunity.logo}
              size="1.6rem"
            />
            <span>You were invited to {inviteCommunity.name}</span>
          </span>
        ) : null}

        {step === 'email' ? <EmailStep flow={flow} /> : null}
        {step === 'code' ? <CodeStep flow={flow} /> : null}
        {step === 'profile' ? (
          <ProfileStep flow={flow} inviteName={inviteCommunity?.name ?? null} />
        ) : null}

        {step === 'email' ? (
          <p className="x-small subtle">
            Posts in public communities are visible to everyone and indexed by search engines.
          </p>
        ) : null}
      </div>
    </main>
  );
}
