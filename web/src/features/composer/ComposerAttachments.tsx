import { Icon, Img, Menu, MenuItem, MenuTitle } from '@/design-system';
import { fmtSize, shortFileName } from '@/domain/format';
import { attachmentSrc, type Attachment } from '@/domain/types';
import { IMAGE_ALIGNS, imageAlignIn, type ImageAlign } from '@/features/markdown/image-align';
import { useUi } from '@/runtime/ui-store';
import type { TextEdits } from './use-text-edits';

const ALIGN_LABEL: Record<ImageAlign, string> = {
  left: 'Align left',
  center: 'Center',
  right: 'Align right',
};

export function ComposerAttachments({
  attachments,
  value,
  edits,
  onRemove,
}: {
  readonly attachments: readonly Attachment[];
  readonly value: string;
  readonly edits: TextEdits;
  readonly onRemove: (f: Attachment) => void;
}) {
  const images = attachments.filter((f) => f.kind === 'image');

  return (
    <div className="attach-list">
      {attachments.map((f) => (
        <div key={f.id} className="attach">
          <AttachmentPreview f={f} />

          <button
            type="button"
            className="attach__remove"
            onClick={() => onRemove(f)}
            aria-label={'Remove ' + f.name}
          >
            <Icon name="x" />
          </button>

          {f.kind === 'image' && edits.placed(f) ? (
            <span
              className="attach__placed"
              data-tip="Shown in the text"
              aria-label="Shown in the text"
            >
              <Icon name="check" />
            </span>
          ) : null}

          {f.kind === 'image' ? (
            <ImageMenu f={f} images={images} value={value} edits={edits} onRemove={onRemove} />
          ) : null}
        </div>
      ))}
    </div>
  );
}

function AttachmentPreview({ f }: { readonly f: Attachment }) {
  if (f.kind === 'image') {
    return (
      <Img src={attachmentSrc(f)} alt={f.name} lazy={false} width={f.width} height={f.height} />
    );
  }

  return (
    <span className="attach__file">
      <Icon name={f.kind === 'video' ? 'video' : 'file'} />
      <span className="file-chip__meta">
        <strong className="truncate" title={f.name}>
          {shortFileName(f.name)}
        </strong>
        <span className="x-small subtle">{fmtSize(f.size)}</span>
      </span>
    </span>
  );
}

function ImageMenu({
  f,
  images,
  value,
  edits,
  onRemove,
}: {
  readonly f: Attachment;
  readonly images: readonly Attachment[];
  readonly value: string;
  readonly edits: TextEdits;
  readonly onRemove: (f: Attachment) => void;
}) {
  const openImage = useUi((s) => s.openImage);

  return (
    <Menu
      className="attach__menu"
      left
      trigger={({ toggle, open }) => (
        <button
          type="button"
          className="attach__more"
          onClick={toggle}
          aria-expanded={open}
          aria-label={'Options for ' + f.name}
          data-tip="Options"
        >
          <Icon name="dots" />
        </button>
      )}
    >
      <MenuTitle>{edits.inCarousel(f) ? 'Carousel position' : 'Position'}</MenuTitle>
      {IMAGE_ALIGNS.map((align) => (
        <MenuItem
          key={align}
          icon={`align-${align}`}
          hint={imageAlignIn(value, f.id) === align ? 'Current' : undefined}
          onSelect={() => edits.alignImage(f, align)}
        >
          {ALIGN_LABEL[align]}
        </MenuItem>
      ))}

      {edits.placed(f) ? (
        <>
          <MenuItem icon="image" onSelect={() => edits.moveImage(f, 'cursor')}>
            Move to cursor
          </MenuItem>
          <MenuItem icon="arrowdown" onSelect={() => edits.moveImage(f, 'end')}>
            Move to the end
          </MenuItem>
          <MenuItem icon="x" onSelect={() => edits.unplace(f)}>
            {edits.inCarousel(f) ? 'Take out of the carousel' : 'Take out of the text'}
          </MenuItem>
        </>
      ) : (
        <>
          <MenuItem icon="image" onSelect={() => edits.placeInText(f, 'cursor')}>
            Place at cursor
          </MenuItem>
          <MenuItem icon="arrowdown" onSelect={() => edits.placeInText(f, 'end')}>
            Place at the end
          </MenuItem>
        </>
      )}
      {images.length > 1 ? (
        <MenuItem icon="grid" onSelect={() => edits.carousel(images)}>
          All {images.length} images as a carousel at cursor
        </MenuItem>
      ) : null}
      <MenuItem icon="eye" onSelect={() => openImage(attachmentSrc(f), f.name, f.download)}>
        View
      </MenuItem>
      <MenuItem icon="trash" danger onSelect={() => onRemove(f)}>
        Remove image
      </MenuItem>
    </Menu>
  );
}
