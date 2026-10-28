import { Button, Icon, Img } from '@/design-system';
import { tintStyle } from '@/domain/format';
import { resizeErrorText, resizeImage } from '@/features/images';
import { useUi } from '@/runtime/ui-store';
import type { CommunityDraft } from './use-community-draft';

export function ImageFields({ draft }: { readonly draft: CommunityDraft }) {
  const flash = useUi((s) => s.flash);
  const { name, hue, banner, setBanner, logo, setLogo } = draft;

  const pickImage = async (
    file: File | undefined,
    width: number,
    height: number,
    square: boolean,
    apply: (url: string) => void,
  ) => {
    if (!file) return;

    const r = await resizeImage(file, width, height, square);

    if (r.ok) apply(r.dataUrl);
    else flash(resizeErrorText(r.error));
  };

  return (
    <>
      <div className="banner-field">
        <div
          className={banner ? 'banner-preview' : 'banner-preview is-default'}
          style={banner ? { backgroundImage: `url(${banner})` } : tintStyle(hue)}
        />

        <div className="banner-field__actions">
          <label className="btn btn--small" data-tip="1600 by 600 works well">
            <input
              type="file"
              accept="image/*"
              className="sr-only"
              onChange={(e) => void pickImage(e.target.files?.[0], 1600, 600, false, setBanner)}
            />
            <Icon name="image" />
            <span>{banner ? 'Change banner' : 'Add a banner'}</span>
          </label>

          {banner ? (
            <Button size="small" className="btn--danger-text" onClick={() => setBanner(null)}>
              Remove
            </Button>
          ) : null}
        </div>

        <label
          className={
            logo ? 'logo-drop logo-drop--overlap has-image' : 'logo-drop logo-drop--overlap'
          }
          style={tintStyle(hue)}
          data-tip="Square works best"
        >
          <input
            type="file"
            accept="image/*"
            className="sr-only"
            onChange={(e) => void pickImage(e.target.files?.[0], 256, 256, true, setLogo)}
          />
          {logo ? (
            <Img src={logo} alt="Logo preview" lazy={false} />
          ) : (
            <span>{(name || 'A')[0]!.toUpperCase()}</span>
          )}
          <span className="logo-drop__badge">
            <Icon name="upload" />
          </span>
        </label>
      </div>

      <div className="logo-field__tools">
        {logo ? (
          <Button
            size="tiny"
            variant="borderless"
            className="btn--danger-text"
            onClick={() => setLogo(null)}
          >
            Remove logo
          </Button>
        ) : null}
      </div>
    </>
  );
}
