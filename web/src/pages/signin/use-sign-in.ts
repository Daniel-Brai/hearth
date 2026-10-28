import { useEffect, useState, type FormEvent } from 'react';
import { useLocation, useNavigate, useSearchParams } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { ok } from '@/data/gateway';
import { useLoad } from '@/data/use-load';
import { routes } from '@/runtime/routes';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';

export type Step = 'email' | 'code' | 'profile';
export type Via = 'email' | 'Google' | 'GitHub';
export type Privacy = 'public' | 'private';
export type Shaking = 'email' | 'code' | 'name' | 'username';

export type NewProfile = {
  readonly name: string;
  readonly username: string;
  readonly privacy: Privacy;
  readonly photo: string | null;
};

const EMAIL_ERROR = "That email doesn't look right. Check it and try again.";

function looksLikeEmail(email: string) {
  const [local, domain, ...rest] = email.split('@');

  if (!local || !domain || rest.length > 0) return false;
  if (email.includes(' ')) return false;

  const dot = domain.lastIndexOf('.');

  return dot > 0 && dot < domain.length - 1;
}

export function useSignIn() {
  const gateway = useGateway();
  const navigate = useNavigate();
  const location = useLocation();
  const [params] = useSearchParams();
  const flash = useUi((s) => s.flash);
  const openDialog = useUi((s) => s.openDialog);

  const inviteCode = params.get('invite');
  const nextPath = params.get('next');

  useLoad(
    () => (inviteCode ? gateway.load.invite(inviteCode) : Promise.resolve(ok(undefined))),
    'invite:' + (inviteCode ?? ''),
  );

  const invite = inviteCode ? gateway.session.inviteByCode(inviteCode) : null;
  const next = nextPath?.startsWith('/') && !nextPath.startsWith('//') ? nextPath : routes.home;

  const [returned] = useState(() => gateway.session.providerReturn());
  const signUp = returned?.kind === 'sign-up' ? returned : null;

  const [step, setStep] = useState<Step>(signUp ? 'profile' : 'email');

  const [via, setVia] = useState<Via>(
    returned && returned.kind !== 'signed-in' ? returned.via : 'email',
  );

  const [busy, setBusy] = useState(false);

  // Going back from Google or GitHub can bring the page back from the browser's cache
  // exactly as it was left, mid redirect, so the button would spin until a reload
  useEffect(() => {
    const restored = (event: PageTransitionEvent) => {
      if (event.persisted) setBusy(false);
    };

    window.addEventListener('pageshow', restored);
    return () => window.removeEventListener('pageshow', restored);
  }, []);
  const [leaving, setLeaving] = useState(false);

  const [error, setError] = useState<string | null>(
    returned?.kind === 'failed' ? returned.error : null,
  );

  const [shaking, setShaking] = useState<Shaking | null>(null);

  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');

  const [seed, setSeed] = useState<{ name: string | null; username: string | null }>({
    name: signUp?.name ?? null,
    username: signUp?.username ?? null,
  });

  const shake = (field: Shaking) => {
    sfx('error');
    setShaking(field);
    window.setTimeout(() => setShaking(null), 450);
  };

  const finish = async (message: string) => {
    if (invite) {
      const r = await gateway.session.acceptInvite(invite.code);

      if (r.ok) {
        flash(message);
        void navigate(routes.community(r.value.community), { replace: true });
        openDialog('welcome', { community: r.value.community });

        return;
      }

      flash(r.error);
    }

    flash(message);
    void navigate(next, { replace: true });
  };

  const startProfile = (initialName: string | null, initialUsername: string | null) => {
    setSeed({ name: initialName, username: initialUsername });
    setError(null);
    setStep('profile');
  };

  const sendCode = async (e: FormEvent) => {
    e.preventDefault();

    const clean = email.trim().toLowerCase();

    if (!looksLikeEmail(clean)) {
      setError(EMAIL_ERROR);
      shake('email');
      return;
    }

    setError(null);
    setVia('email');
    setBusy(true);

    const r = await gateway.session.requestCode(clean).finally(() => setBusy(false));

    if (!r.ok) {
      setError(r.error);
      return;
    }

    setEmail(clean);
    setCode('');
    setStep('code');
  };

  const verify = async (digits: string) => {
    setBusy(true);

    const r = await gateway.session.verifyCode(email, digits).finally(() => setBusy(false));

    if (!r.ok) {
      setError(r.error);
      setCode('');
      shake('code');

      return;
    }

    if (r.value.known) void finish('Welcome back');
    else startProfile(null, email.slice(0, email.indexOf('@')));
  };

  const changeCode = (next: string) => {
    setCode(next);
    setError(null);

    if (next.length === 6) void verify(next);
  };

  const oauth = async (provider: 'Google' | 'GitHub') => {
    setVia(provider);
    setBusy(true);

    const r = await gateway.session
      .oauth(provider, location.pathname + location.search)
      .finally(() => setBusy(false));

    if (!r.ok) {
      setError(r.error);
      return;
    }

    if (!r.value) {
      setLeaving(true);
      return;
    }

    startProfile(r.value.name, r.value.username);
    flash('Connected your ' + provider + ' account');
  };

  const reject = (text: string, field: Shaking | null) => {
    setError(text);
    if (field) shake(field);
  };

  const completeSignup = async (profile: NewProfile) => {
    setError(null);
    setBusy(true);

    const r = await gateway.session
      .completeSignup({
        email: via === 'email' ? email : null,
        name: profile.name,
        username: profile.username,
        private: profile.privacy === 'private',
        photo: profile.photo,
      })
      .finally(() => setBusy(false));

    if (!r.ok) {
      setError(r.error);
      return;
    }

    const greeting =
      profile.privacy === 'private' ? `@${profile.username}` : profile.name.split(' ')[0];

    void finish(`Welcome to Hearth, ${greeting}`);
  };

  const back = () => {
    setStep('email');
    setCode('');
    setError(null);
  };

  const signedInTo =
    returned?.kind === 'signed-in' ? (inviteCode ? routes.join(inviteCode) : next) : null;

  return {
    signedInTo,
    invite,
    step,
    via,
    busy: busy || leaving,
    error,
    shaking,
    email,
    setEmail,
    code,
    seed,
    sendCode,
    changeCode,
    oauth,
    reject,
    completeSignup,
    back,
    resend: () => flash('Sent a new code to ' + email),
  };
}

export type SignIn = ReturnType<typeof useSignIn>;
