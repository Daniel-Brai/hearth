import { useState, type KeyboardEvent } from 'react';
import { useNavigate, useParams } from 'react-router';
import {
  Button,
  ButtonLink,
  Field,
  HUE_CHOICES,
  Input,
  Keys,
  Measure,
  Panel,
  Segmented,
  Swatches,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { AudienceField } from '@/features/community/AudienceField';
import { DescriptionField } from '@/features/composer/DescriptionField';
import { canDo, community, isOwner } from '@/domain/selectors';
import type { ModerationLevel } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { LeaveDialog } from '@/pages/compose/LeaveDialog';
import { useLeaveGuard } from '@/pages/compose/use-leave-guard';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { CategoriesField } from './CategoriesField';
import { ImageFields } from './ImageFields';
import { KindsField } from './KindsField';
import { LinksEditor } from './LinksEditor';
import { OwnershipField } from './OwnershipField';
import { useCommunityDraft, type CommunityDraft } from './use-community-draft';
import { useSaveCommunity } from './use-save-community';
import './EditCommunityPage.css';

const LEVELS: { value: ModerationLevel; label: string }[] = [
  { value: 'full', label: 'Full' },
  { value: 'reports', label: 'Reports only' },
  { value: 'none', label: 'None' },
];

const LEVEL_HINT: Record<ModerationLevel, string> = {
  full: 'Holds posts and messages that might break the rules. People can report too.',
  reports: 'No automatic checks. Only what people report goes to the queue.',
  none: "No checks and no reports. People see it isn't moderated.",
};

// Everything the form changes, without the ids rows only need while editing
const snapshotOf = (d: CommunityDraft) =>
  JSON.stringify([
    d.name,
    d.hue,
    d.tagline,
    d.intro,
    d.logo,
    d.banner,
    d.categories,
    d.moderation,
    d.audience,
    d.links.map(({ id: _id, ...link }) => link),
    d.kinds.map(({ id: _id, ...kind }) => kind),
  ]);

export function EditCommunityPage() {
  const { community: cid } = useParams();
  const gateway = useGateway();

  const load = useLoad(
    () => (cid ? gateway.load.community(cid) : Promise.resolve({ ok: true, value: undefined })),
    'community:' + (cid ?? 'none'),
  );

  const exists = useAppState((state) => !!cid && !!community(state, cid));
  const allowed = useAppState((state) => !!cid && canDo(state, cid, 'community.update'));

  if (load.status === 'error') return <ErrorPage code={500} />;
  if (!cid || !exists) return <ErrorPage code={404} />;
  if (!allowed) return <ErrorPage code={403} forbidden="editors" />;

  // Keyed by community so opening another starts a fresh form
  return <EditCommunityForm key={cid} cid={cid} />;
}

function EditCommunityForm({ cid }: { readonly cid: string }) {
  const navigate = useNavigate();

  const current = useAppState((state) => community(state, cid)!);
  const owner = useAppState((state) => isOwner(state, cid));

  const draft = useCommunityDraft(current);
  const [initial] = useState(() => snapshotOf(draft));

  const dirty = snapshotOf(draft) !== initial;
  const guard = useLeaveGuard(dirty);

  const done = () => {
    guard.allowLeave();
    void navigate(routes.community(cid));
  };

  const { save, shake } = useSaveCommunity(cid, draft, done);

  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) void save();
  };

  return (
    <>
      <PageHeader label="edit community" eyebrow={current.name} title="Edit community" />

      <main id="main">
        <form
          id="edit-community-form"
          noValidate
          onKeyDown={onKey}
          onSubmit={(e) => {
            e.preventDefault();
            void save();
          }}
        >
          <Measure narrow className="grid gap-4 edit-community">
            <Panel className="grid gap-3" id="edit-community-identity">
              <ImageFields draft={draft} />

              <div className="form-grid">
                <Field label="Name">
                  <Input
                    id="edit-c-name"
                    value={draft.name}
                    onChange={(e) => draft.setName(e.target.value)}
                    maxLength={40}
                    shake={shake}
                  />
                </Field>

                <Field label="Color" as="div">
                  <Swatches
                    name="edit-hue"
                    value={draft.hue}
                    hues={HUE_CHOICES}
                    onChange={draft.setHue}
                  />
                </Field>
              </div>

              <Field label="Tagline">
                <Input
                  value={draft.tagline}
                  onChange={(e) => draft.setTagline(e.target.value)}
                  maxLength={80}
                />
              </Field>
            </Panel>

            <Panel className="grid gap-3" id="edit-community-about">
              <h2 className="section-title">About</h2>

              <DescriptionField
                id="edit-c-about"
                value={draft.intro}
                onChange={draft.setIntro}
                community={cid}
              />

              <CategoriesField draft={draft} />

              <Field label="Links" as="div">
                <LinksEditor links={draft.links} onChange={draft.setLinks} />
              </Field>
            </Panel>

            <Panel className="grid gap-3" id="edit-community-posts">
              <h2 className="section-title">Access and posts</h2>

              <Field label="Moderation" as="div" hint={LEVEL_HINT[draft.moderation]}>
                <Segmented
                  name="c-moderation"
                  label="Moderation"
                  value={draft.moderation}
                  onChange={draft.setModeration}
                  options={LEVELS}
                  className="justify-self-start"
                />
              </Field>

              <AudienceField
                name="edit-community-audience"
                value={draft.audience}
                onChange={draft.setAudience}
              />

              <KindsField cid={cid} draft={draft} />
            </Panel>

            {owner ? (
              <Panel className="grid gap-3" id="edit-community-owner">
                <OwnershipField cid={cid} name={current.name} close={done} />
              </Panel>
            ) : null}

            <div className="edit-community__bar">
              {dirty ? <span className="x-small subtle">Unsaved changes</span> : null}
              <ButtonLink to={routes.community(cid)}>Cancel</ButtonLink>
              <Button type="submit" variant="reversed">
                Save changes
                <Keys combo="mod+enter" />
              </Button>
            </div>
          </Measure>
        </form>
      </main>

      <LeaveDialog
        blocker={guard.blocker}
        title="Leave without saving?"
        text="Your changes to this community haven't been saved."
        stay="Keep editing"
        leave="Discard changes"
      />
    </>
  );
}
