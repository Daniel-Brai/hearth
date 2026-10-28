import { useEffect, useState } from 'react';
import { Field, HUE_CHOICES, Input, Swatches } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useOrigin } from '@/app/request-context';
import { AudienceField } from '@/features/community/AudienceField';
import { DescriptionField } from '@/features/composer/DescriptionField';
import type { Template } from '@/domain/types';
import { slugify } from '@/runtime/routes';
import type { Form } from './form';

export function CommunityFields({
  form,
  template,
  asRequest,
  shake,
  set,
}: {
  readonly form: Form;
  readonly template: Template;
  readonly asRequest: boolean;
  readonly shake: boolean;
  readonly set: <K extends keyof Form>(key: K, value: Form[K]) => void;
}) {
  const origin = useOrigin();
  const host = origin ? new URL(origin).host : '';
  const slug = useAddress(form.name);

  return (
    <>
      <Field
        label="Name"
        hint={
          <span>
            Address: {host}/c/<strong>{slug}</strong>
          </span>
        }
      >
        <Input
          id="new-community-name"
          value={form.name}
          onChange={(e) => set('name', e.target.value)}
          placeholder={template.ph.name}
          maxLength={40}
          shake={shake}
          autoFocus
        />
      </Field>

      <Field label="Tagline">
        <Input
          id="new-community-tagline"
          value={form.tagline}
          onChange={(e) => set('tagline', e.target.value)}
          placeholder={template.ph.tagline}
          maxLength={80}
        />
      </Field>

      <DescriptionField
        id="new-community-description"
        value={form.description}
        onChange={(description) => set('description', description)}
        community={null}
      />

      <Field label="Color" as="div">
        <Swatches name="hue" value={form.hue} hues={HUE_CHOICES} onChange={(h) => set('hue', h)} />
      </Field>

      <AudienceField
        name="new-community-audience"
        value={form.audience}
        onChange={(audience) => set('audience', audience)}
      />

      {asRequest ? (
        <Field
          label={
            <>
              Why this community? <span className="subtle">(optional)</span>
            </>
          }
        >
          <Input
            value={form.note}
            onChange={(e) => set('note', e.target.value)}
            maxLength={200}
            placeholder="A line for the admin"
          />
        </Field>
      ) : null}
    </>
  );
}

// Asks the server once typing pauses since a taken name gets a number, and guesses until then
function useAddress(name: string) {
  const gateway = useGateway();
  const [answer, setAnswer] = useState<{ name: string; slug: string } | null>(null);

  const trimmed = name.trim();

  useEffect(() => {
    if (!trimmed) return;

    const timer = window.setTimeout(() => {
      void gateway.communities.slugFor(trimmed).then((slug) => {
        if (slug) setAnswer({ name: trimmed, slug });
      });
    }, 300);

    return () => window.clearTimeout(timer);
  }, [gateway, trimmed]);

  if (!trimmed) return 'your-community';
  if (answer?.name === trimmed) return answer.slug;

  return slugify(trimmed) || 'community';
}
