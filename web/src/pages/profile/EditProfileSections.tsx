import {
  Avatar,
  Button,
  CharCount,
  ChoiceTiles,
  Field,
  Icon,
  Input,
  InputWithPrefix,
  Panel,
  Segmented,
  SettingsRow,
  Select,
  Textarea,
} from '@/design-system';
import { linkIcon, linkText } from '@/domain/links';
import type { CommunitiesVisibility, Visibility } from '@/domain/types';
import { Markdown } from '@/features/markdown/Markdown';
import { BIO_MAX, type LinkRow } from './edit-profile-form';
import type { EditProfile } from './use-edit-profile';

const VISIBILITY: { value: Visibility; label: string }[] = [
  { value: 'everyone', label: 'Everyone' },
  { value: 'members', label: 'People in your communities' },
  { value: 'nobody', label: 'Nobody' },
];

const COMMUNITIES: { value: CommunitiesVisibility; label: string }[] = [
  { value: 'common', label: 'Only ones you share' },
  { value: 'everyone', label: 'All of them' },
  { value: 'nobody', label: 'None' },
];

const PHOTO_TYPES = 'image/png,image/jpeg,image/webp,image/gif';

type Identity = { readonly initials: string; readonly hue: string; readonly username: string };

type SectionProps = { readonly edit: EditProfile };

export function IdentityPanel({ edit, identity }: SectionProps & { readonly identity: Identity }) {
  const { form, set } = edit;

  return (
    <Panel className="grid gap-4">
      <PhotoField edit={edit} identity={identity} />

      <div className="grid gap-2">
        <div className="form-grid">
          <Field label="Name">
            <Input
              id="pf-name"
              value={form.name}
              onChange={(e) => set('name', e.target.value)}
              maxLength={50}
              autoComplete="name"
              shake={edit.shake === 'name'}
            />
          </Field>
          <Field label="Username" as="div">
            <InputWithPrefix
              prefix="@"
              id="pf-username"
              value={identity.username}
              readOnly
              aria-describedby="pf-username-hint"
            />
          </Field>
        </div>
        <p className="field__hint m-0" id="pf-username-hint">
          People mention you as <strong>@{identity.username}</strong>. It can't be changed.
        </p>
      </div>

      <div className="form-grid">
        <Field
          label={
            <>
              Pronouns <span className="subtle">(optional)</span>
            </>
          }
        >
          <Input
            value={form.pronouns}
            onChange={(e) => set('pronouns', e.target.value)}
            maxLength={24}
            placeholder="she/her, they/them"
          />
        </Field>
        <Field
          label={
            <>
              Location <span className="subtle">(optional)</span>
            </>
          }
        >
          <Input
            value={form.location}
            onChange={(e) => set('location', e.target.value)}
            maxLength={40}
            placeholder="City or timezone"
          />
        </Field>
      </div>

      {form.hidden ? (
        <p className="field__hint -mt-2.5">
          Your location stays hidden while only your username is shown.
        </p>
      ) : null}
    </Panel>
  );
}

function PhotoField({ edit, identity }: SectionProps & { readonly identity: Identity }) {
  const { form, set, pickPhoto } = edit;

  return (
    <div className="photo-field">
      <label className="contents">
        <input
          type="file"
          accept={PHOTO_TYPES}
          className="sr-only"
          aria-label="Upload a photo"
          onChange={(e) => void pickPhoto(e.target.files?.[0])}
        />
        <Avatar
          size="xl"
          className="avatar--editable"
          hue={identity.hue}
          initials={identity.initials}
          photo={form.photo}
        >
          <span className="avatar__badge">
            <Icon name="upload" />
          </span>
        </Avatar>
      </label>

      <div className="grid gap-1">
        <strong className="small">
          Photo <span className="subtle font-normal">(optional)</span>
        </strong>
        <span className="x-small subtle">
          A square image works best. PNG, JPG, WebP or GIF up to 8 MB.
        </span>
        <div className="flex gap-2 flex-wrap mt-1">
          <label className="btn btn--small">
            <input
              type="file"
              accept={PHOTO_TYPES}
              className="sr-only"
              onChange={(e) => void pickPhoto(e.target.files?.[0])}
            />
            <Icon name="upload" />
            <span>{form.photo ? 'Change photo' : 'Upload photo'}</span>
          </label>
          {form.photo ? (
            <Button
              size="small"
              variant="borderless"
              className="btn--danger-text"
              onClick={() => set('photo', null)}
            >
              Remove
            </Button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

export function BioPanel({
  edit,
  preview,
  onPreview,
}: SectionProps & {
  readonly preview: boolean;
  readonly onPreview: (preview: boolean) => void;
}) {
  const { form, set } = edit;

  return (
    <Panel className="grid gap-2">
      <div className="flex items-center justify-between gap-2">
        <h2 className="section-title">Bio</h2>
        <Segmented
          tiny
          name="pf-tab"
          value={preview ? 'preview' : 'write'}
          onChange={(v) => onPreview(v === 'preview')}
          label="Write or preview the bio"
          options={[
            { value: 'write', label: 'Write' },
            { value: 'preview', label: 'Preview' },
          ]}
        />
      </div>

      {preview ? (
        <div className="input bio-input bio-preview">
          {form.bio.trim() ? (
            <Markdown text={form.bio} community={null} />
          ) : (
            <span className="subtle">Nothing written yet.</span>
          )}
        </div>
      ) : (
        <Textarea
          id="pf-bio"
          className="bio-input"
          value={form.bio}
          onChange={(e) => set('bio', e.target.value)}
          rows={6}
          shake={edit.shake === 'bio'}
          placeholder="What you work on, what you are happy to help with. Links and @mentions work."
          aria-label="Bio"
          aria-invalid={BIO_MAX - form.bio.length < 0}
        />
      )}

      <div className="flex items-center justify-between gap-2 x-small">
        <span className="subtle">
          Shown on your profile. The first line also shows when people hover your name.
        </span>
        <CharCount value={form.bio} max={BIO_MAX} />
      </div>
    </Panel>
  );
}

export function LinksPanel({ edit }: SectionProps) {
  const { form, links } = edit;

  return (
    <Panel className="grid gap-3">
      <div className="grid">
        <h2 className="section-title">Links</h2>
        <span className="x-small subtle">
          Add as many as you like. Common sites get their icon and label on their own.
        </span>
      </div>

      {form.links.map((l, i) => (
        <LinkRowEditor
          key={l.id}
          row={l}
          index={i}
          last={i === form.links.length - 1}
          shaking={edit.shake === `link-${l.id}`}
          links={links}
        />
      ))}

      <div>
        <Button size="small" onClick={links.add}>
          <Icon name="plus" />
          Add a link
        </Button>
      </div>
    </Panel>
  );
}

function LinkRowEditor({
  row: l,
  index: i,
  last,
  shaking,
  links,
}: {
  readonly row: LinkRow;
  readonly index: number;
  readonly last: boolean;
  readonly shaking: boolean;
  readonly links: EditProfile['links'];
}) {
  return (
    <div className="link-row">
      <span className="link-row__icon">
        <Icon name={linkIcon(l.url)} />
      </span>
      <Input
        id={`pf-link-${l.id}`}
        type="url"
        inputMode="url"
        value={l.url}
        onChange={(e) => links.changeUrl(l, e.target.value)}
        placeholder="yoursite.dev, youtube.com/@you, ko-fi.com/you"
        aria-label="Link address"
        spellCheck={false}
        shake={shaking}
        autoFocus={!l.url && last}
      />
      <Input
        className="link-row__label"
        value={l.label}
        onChange={(e) =>
          links.setLink(l.id, { label: e.target.value, auto: !e.target.value.trim() })
        }
        maxLength={30}
        placeholder={linkText({ url: l.url, label: null }) || 'Label (optional)'}
        aria-label="Label (optional)"
      />
      <div className="link-row__tools">
        <Button
          circle
          size="small"
          variant="borderless"
          disabled={i === 0}
          onClick={() => links.move(i, -1)}
          aria-label="Move up"
          data-tip="Move up"
        >
          <Icon name="chevron" style={{ rotate: '180deg' }} />
        </Button>
        <Button
          circle
          size="small"
          variant="borderless"
          disabled={last}
          onClick={() => links.move(i, 1)}
          aria-label="Move down"
          data-tip="Move down"
        >
          <Icon name="chevron" />
        </Button>
        <Button
          circle
          size="small"
          variant="borderless"
          onClick={() => links.remove(l.id)}
          aria-label="Remove link"
          data-tip="Remove"
        >
          <Icon name="x" />
        </Button>
      </div>
    </div>
  );
}

export function PrivacyPanel({ edit, username }: SectionProps & { readonly username: string }) {
  const { form, set } = edit;

  return (
    <Panel className="grid gap-3">
      <div className="grid">
        <h2 className="section-title">Privacy</h2>
        <span className="x-small subtle">
          What others see on your posts, messages, voice rooms and public pages.
        </span>
      </div>

      <ChoiceTiles
        name="privacy"
        value={form.hidden ? 'private' : 'public'}
        onChange={(v) => set('hidden', v === 'private')}
        label="What others see"
        tiles={[
          {
            value: 'public',
            icon: 'user',
            label: form.name.trim() || 'Your name',
            sub: `Name and @${username}`,
          },
          {
            value: 'private',
            icon: 'eyeoff',
            label: `@${username}`,
            sub: 'Username only. Your name, location and email stay private.',
          },
        ]}
      />

      <div className="grid">
        <SettingsRow
          title="Online status and last seen"
          sub="The green dot and “Last seen”. Hiding yours doesn't hide other people's."
        >
          <Select
            value={form.presence}
            options={VISIBILITY}
            onChange={(v) => set('presence', v)}
            label="Who sees your online status"
          />
        </SettingsRow>
        <SettingsRow
          title="Your communities"
          sub="Which of your communities others can see on your profile."
        >
          <Select
            value={form.commsVis}
            options={COMMUNITIES}
            onChange={(v) => set('commsVis', v)}
            label="Who sees your communities"
          />
        </SettingsRow>
        <SettingsRow title="Profile photo" sub="People who can't see it get your initials instead.">
          <Select
            value={form.photoVis}
            options={VISIBILITY}
            onChange={(v) => set('photoVis', v)}
            label="Who sees your photo"
          />
        </SettingsRow>
      </div>
    </Panel>
  );
}
