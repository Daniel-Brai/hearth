import { useState, type KeyboardEvent } from 'react';
import { Button, ButtonLink, Keys, Measure } from '@/design-system';
import { useAppState } from '@/data/store';
import { initials, person } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { LeaveDialog } from '@/pages/compose/LeaveDialog';
import { BIO_MAX } from './edit-profile-form';
import { BioPanel, IdentityPanel, LinksPanel, PrivacyPanel } from './EditProfileSections';
import { useEditProfile } from './use-edit-profile';
import './EditProfilePage.css';

export function EditProfilePage() {
  const me = useAppState((state) => state.me);
  const loaded = useAppState((state) => !!state.me && !!state.people[state.me]);

  if (!me || !loaded) return null;

  // Keyed by person so switching people starts a fresh form
  return <EditProfileForm key={me} me={me} />;
}

function EditProfileForm({ me }: { readonly me: string }) {
  const identity = useAppState((state) => ({
    initials: initials(state, me),
    hue: person(state, me).hue,
    username: person(state, me).username,
  }));

  const edit = useEditProfile(me, identity.username);
  const [preview, setPreview] = useState(false);

  const bioLeft = BIO_MAX - edit.form.bio.length;

  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) edit.submit();
  };

  return (
    <>
      <PageHeader label="edit profile" title="Edit profile" />

      <main id="main">
        <form onSubmit={edit.submit} onKeyDown={onKey} noValidate id="profile-form">
          <Measure narrow className="grid gap-4 edit-profile">
            <IdentityPanel edit={edit} identity={identity} />
            <BioPanel edit={edit} preview={preview} onPreview={setPreview} />
            <LinksPanel edit={edit} />
            <PrivacyPanel edit={edit} username={identity.username} />

            {edit.problem ? (
              <p className="field__error" role="alert">
                {edit.problem.text}
              </p>
            ) : null}

            <div className="edit-profile__bar">
              {edit.dirty ? <span className="x-small subtle">Unsaved changes</span> : null}
              <ButtonLink to={routes.profile(identity.username)}>Cancel</ButtonLink>
              <Button type="submit" variant="reversed" disabled={bioLeft < 0}>
                Save
                <Keys combo="mod+enter" />
              </Button>
            </div>
          </Measure>
        </form>
      </main>

      <LeaveDialog
        blocker={edit.blocker}
        title="Leave without saving?"
        text="Your changes to your profile haven't been saved."
        stay="Keep editing"
        leave="Discard changes"
      />
    </>
  );
}
