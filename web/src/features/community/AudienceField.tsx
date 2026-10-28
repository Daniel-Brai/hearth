import { Field, cn } from '@/design-system';
import { AUDIENCE_LABEL, type Audience } from '@/domain/audience';
import './AudienceField.css';

const OPTIONS: readonly { value: Audience; label: string; text: string }[] = [
  {
    value: 'indexed',
    label: AUDIENCE_LABEL.indexed,
    text: 'Anyone can read and join. Search engines list it.',
  },
  {
    value: 'public',
    label: AUDIENCE_LABEL.public,
    text: 'Anyone with the link can read and join. Kept out of search.',
  },
  {
    value: 'invite',
    label: AUDIENCE_LABEL.invite,
    text: 'People can see its name and look. Joining takes an invite.',
  },
  {
    value: 'private',
    label: AUDIENCE_LABEL.private,
    text: 'Hidden from everyone but members. Joining takes an invite.',
  },
];

export function AudienceField({
  name,
  value,
  onChange,
}: {
  readonly name: string;
  readonly value: Audience;
  readonly onChange: (next: Audience) => void;
}) {
  return (
    <Field label="Who can see it?" as="div">
      <div className="audience-list" role="radiogroup" aria-label="Who can see it">
        {OPTIONS.map((o) => (
          <label key={o.value} className={cn('audience-row', value === o.value && 'is-on')}>
            <input
              type="radio"
              name={name}
              value={o.value}
              checked={value === o.value}
              onChange={() => onChange(o.value)}
            />
            <span className="grid">
              <strong className="small">{o.label}</strong>
              <span className="x-small subtle">{o.text}</span>
            </span>
          </label>
        ))}
      </div>
    </Field>
  );
}
