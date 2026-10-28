import { useState } from 'react';
import { Field, Segmented } from '@/design-system';
import { Markdown } from '@/features/markdown/Markdown';
import { Composer } from './Composer';
import './DescriptionField.css';

const PLACEHOLDER =
  'What this community is for, how to ask good questions, house rules. Formatting works.';

// The same editor as a post, without files, with a preview of how it will read
export function DescriptionField({
  id,
  value,
  onChange,
  community,
}: {
  readonly id: string;
  readonly value: string;
  readonly onChange: (next: string) => void;
  readonly community: string | null;
}) {
  const [preview, setPreview] = useState(false);

  return (
    <Field
      as="div"
      label={
        <span className="flex items-center justify-between gap-2">
          Description
          <Segmented
            tiny
            name={id + '-tab'}
            value={preview ? 'preview' : 'write'}
            onChange={(v) => setPreview(v === 'preview')}
            label="Write or preview the description"
            options={[
              { value: 'write', label: 'Write' },
              { value: 'preview', label: 'Preview' },
            ]}
          />
        </span>
      }
    >
      {preview ? (
        <div className="input description-preview">
          {value.trim() ? (
            <Markdown text={value} community={community} />
          ) : (
            <span className="subtle">Nothing written yet.</span>
          )}
        </div>
      ) : (
        <Composer
          id={id}
          variant="body"
          label="Description"
          value={value}
          onChange={onChange}
          maxLength={1200}
          community={community}
          placeholder={PLACEHOLDER}
        />
      )}
    </Field>
  );
}
