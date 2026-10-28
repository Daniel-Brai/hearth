import { useState, type FormEvent } from 'react';
import { Button, ChoiceTiles, Field, Input, InputWithPrefix } from '@/design-system';
import { useAppState } from '@/data/store';
import { stripPrefix } from '@/domain/links';
import { isUsername, takenText, toUsername, usernameProblem } from '@/domain/username';
import { PhotoField } from '@/pages/signin/PhotoField';
import type { SignIn, Privacy } from './use-sign-in';
import { useUsernameTaken } from './use-username-taken';

const initialsOf = (name: string) =>
  name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0]!.toUpperCase())
    .join('') || '?';

export function ProfileStep({
  flow,
  inviteName,
}: {
  readonly flow: SignIn;
  readonly inviteName: string | null;
}) {
  const { via, busy, error, shaking, seed } = flow;

  const [name, setName] = useState(seed.name ?? '');
  const [username, setUsername] = useState(() => toUsername(seed.username ?? ''));
  const [privacy, setPrivacy] = useState<Privacy>('public');
  const [photo, setPhoto] = useState<string | null>(null);
  const [agree, setAgree] = useState(false);

  const cleanUsername = stripPrefix(username.trim().toLowerCase(), ['@']);
  const localProblem = useAppState((state) => usernameProblem(state, cleanUsername, null));
  const seq = useAppState((state) => state.seq);
  const taken = useUsernameTaken(cleanUsername, isUsername(cleanUsername));
  const problem = localProblem ?? (taken ? takenText(cleanUsername, seq) : null);

  const submit = (e: FormEvent) => {
    e.preventDefault();

    if (!name.trim()) return flow.reject('Add your name. You can keep it private below.', 'name');
    if (problem) return flow.reject(problem, 'username');
    if (!agree) return flow.reject('Agree to the community guidelines to continue.', null);

    void flow.completeSignup({ name: name.trim(), username: cleanUsername, privacy, photo });
  };

  return (
    <form id="signup-form" className="grid gap-3" style={{ textAlign: 'start' }} onSubmit={submit}>
      <div className="text-center grid gap-1 mb-6">
        <h1 className="page-title">Set up your profile</h1>
        <p className="subtle">
          {via === 'email'
            ? 'One last step before you join.'
            : 'We filled this in from ' + via + '. Change anything you like.'}
        </p>
      </div>

      <PhotoField photo={photo} initials={initialsOf(name)} onChange={setPhoto} />

      <Field label="Name">
        <Input
          id="signup-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          maxLength={50}
          autoComplete="name"
          placeholder="Your name"
          shake={shaking === 'name'}
          autoFocus={!name}
        />
      </Field>

      <Field
        label="Username"
        hint={
          <span style={problem ? { color: 'var(--color-negative)' } : undefined}>
            {problem ?? `People can mention you as @${cleanUsername}. You can't change it later.`}
          </span>
        }
      >
        <InputWithPrefix
          id="signup-username"
          prefix="@"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          maxLength={20}
          autoComplete="username"
          spellCheck={false}
          placeholder="username"
          shake={shaking === 'username'}
          autoFocus={!!name}
        />
      </Field>

      <Field label="What should others see?" as="div">
        <ChoiceTiles
          name="signup-privacy"
          label="What others see"
          value={privacy}
          onChange={setPrivacy}
          tiles={[
            {
              value: 'public',
              icon: 'user',
              label: name || 'Your name',
              sub: 'Name and username',
            },
            {
              value: 'private',
              icon: 'eyeoff',
              label: '@' + (cleanUsername || 'username'),
              sub: 'Username only, name stays private',
            },
          ]}
        />
      </Field>

      <label className="icon-text small">
        <input
          id="signup-agree"
          type="checkbox"
          checked={agree}
          onChange={(e) => setAgree(e.target.checked)}
          style={{
            inlineSize: '1.05rem',
            blockSize: '1.05rem',
            accentColor: 'var(--color-link)',
          }}
        />
        I agree to be kind and follow each community's guidelines
      </label>

      {error ? <p className="field__error">{error}</p> : null}

      <Button type="submit" variant="reversed" block busy={busy}>
        {inviteName ? 'Create account and join ' + inviteName : 'Create account'}
      </Button>
    </form>
  );
}
