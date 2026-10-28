import type { CSSProperties } from 'react';
import { Button, Icon, Img } from '@/design-system';
import { resizeErrorText, resizeImage } from '@/features/images';
import { useUi } from '@/runtime/ui-store';

const ACCEPT = 'image/png,image/jpeg,image/webp,image/gif';

export type PhotoFieldProps = {
  readonly photo: string | null;
  readonly initials: string;
  readonly onChange: (photo: string | null) => void;
};

export function PhotoField({ photo, initials, onChange }: PhotoFieldProps) {
  const flash = useUi((s) => s.flash);

  const pick = async (file: File | undefined) => {
    if (!file) return;

    const r = await resizeImage(file, 320, 320, true);

    if (r.ok) onChange(r.dataUrl);
    else flash(resizeErrorText(r.error));
  };

  return (
    <div className="photo-field">
      <label
        className="avatar avatar--xl avatar--editable"
        style={{ '--av': 'var(--hue-blue)' } as CSSProperties}
      >
        <input
          type="file"
          accept={ACCEPT}
          className="sr-only"
          aria-label="Upload a photo"
          onChange={(e) => void pick(e.target.files?.[0])}
        />
        {photo ? <Img src={photo} alt="Your avatar" lazy={false} /> : <span>{initials}</span>}
        <span className="avatar__badge">
          <Icon name="upload" />
        </span>
      </label>

      <div className="grid gap-1">
        <strong className="small">
          Photo{' '}
          <span className="subtle" style={{ fontWeight: 400 }}>
            (optional)
          </span>
        </strong>
        <span className="x-small subtle">
          A square image works best. PNG, JPG, WebP or GIF up to 8 MB.
        </span>

        <div className="flex gap-2 flex-wrap" style={{ marginBlockStart: '0.3rem' }}>
          <label className="btn btn--small">
            <input
              type="file"
              accept={ACCEPT}
              className="sr-only"
              onChange={(e) => void pick(e.target.files?.[0])}
            />
            <Icon name="upload" />
            <span>{photo ? 'Change photo' : 'Upload photo'}</span>
          </label>

          {photo ? (
            <Button
              size="small"
              variant="borderless"
              className="btn--danger-text"
              onClick={() => onChange(null)}
            >
              Remove
            </Button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
