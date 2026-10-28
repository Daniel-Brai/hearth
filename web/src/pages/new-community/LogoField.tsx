import { Button, Icon, Img } from '@/design-system';
import { tintStyle } from '@/domain/format';
import type { Form } from './form';

export function LogoField({
  form,
  onPick,
  onRemove,
}: {
  readonly form: Form;
  readonly onPick: (file: File | undefined) => void;
  readonly onRemove: () => void;
}) {
  return (
    <div className="logo-field">
      <label
        className={form.logo ? 'logo-drop has-image' : 'logo-drop'}
        style={tintStyle(form.hue)}
      >
        <input
          type="file"
          accept="image/*"
          className="sr-only"
          onChange={(e) => onPick(e.target.files?.[0])}
        />
        {form.logo ? (
          <Img src={form.logo} alt="Logo preview" lazy={false} />
        ) : (
          <span>{(form.name || 'A')[0]!.toUpperCase()}</span>
        )}
        <span className="logo-drop__badge">
          <Icon name="upload" />
        </span>
      </label>

      <div className="grid gap-1">
        <strong className="small">Logo</strong>
        <span className="x-small subtle">
          Square images look best. Without one we use your color and first letter.
        </span>
        {form.logo ? (
          <Button
            size="tiny"
            variant="borderless"
            className="btn--danger-text"
            style={{ justifySelf: 'start' }}
            onClick={onRemove}
          >
            Remove logo
          </Button>
        ) : null}
      </div>
    </div>
  );
}
