import { Dialog, ExternalButtonLink, Icon, Img } from '@/design-system';
import { useUi } from '@/runtime/ui-store';

export function Lightbox() {
  const open = useUi((s) => s.dialog === 'lightbox');
  const image = useUi((s) => s.lightbox);
  const closeDialog = useUi((s) => s.closeDialog);

  const close = () => closeDialog('lightbox');

  return (
    <Dialog open={open && !!image} onClose={close} className="dialog--lightbox" label="Image">
      {image ? (
        <>
          <button
            type="button"
            className="lightbox__image"
            onClick={close}
            aria-label="Close image"
          >
            <Img src={image.src} alt={image.name} lazy={false} />
          </button>
          <div className="lightbox__bar">
            <span className="truncate">{image.name}</span>
            <ExternalButtonLink
              size="small"
              href={image.download}
              download={image.name}
              onClick={(e) => e.stopPropagation()}
            >
              <Icon name="download" />
              Download
            </ExternalButtonLink>
          </div>
        </>
      ) : null}
    </Dialog>
  );
}
