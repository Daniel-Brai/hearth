import { useState } from 'react';
import { Icon } from '@/design-system/icons/Icon';
import { IconButton } from './button';
import { Carousel } from './carousel';
import { Img } from './image';
import { VideoAttachment } from './video-attachment';
import { fmtSize, shortFileName } from '@/domain/format';
import {
  attachmentDownload,
  attachmentSrc,
  type Attachment,
  type LinkPreview as LinkPreviewData,
} from '@/domain/types';

export function FileList({
  files,
  onOpenImage,
}: {
  readonly files: readonly Attachment[];
  readonly onOpenImage: (f: Attachment) => void;
}) {
  if (!files.length) return null;

  const images = files.filter((f) => f.kind === 'image');
  const gallery = images.length > 1;

  return (
    <div className="files">
      {gallery ? (
        <Carousel
          label={`${images.length} images`}
          images={images.map((f) => ({
            key: f.id,
            src: attachmentSrc(f),
            alt: f.name,
            width: f.width,
            height: f.height,
          }))}
          onOpen={(i) => onOpenImage(images[i]!)}
        />
      ) : null}

      {(gallery ? files.filter((f) => f.kind !== 'image') : files).map((f) => (
        <div key={f.id}>
          {f.kind === 'video' ? <VideoAttachment file={f} /> : null}

          {f.kind === 'image' ? (
            <button
              type="button"
              className="file-image-button"
              onClick={() => onOpenImage(f)}
              aria-label={'Open ' + f.name}
            >
              <Img
                className="file-image"
                src={attachmentSrc(f)}
                alt={f.name}
                width={f.width}
                height={f.height}
              />
            </button>
          ) : null}

          {f.kind === 'file' ? (
            <a
              className="file-chip"
              href={attachmentDownload(f)}
              download={f.name}
              target="_blank"
              rel="noopener"
            >
              <Icon name="file" />
              <span className="file-chip__meta">
                <strong className="truncate" title={f.name}>
                  {shortFileName(f.name)}
                </strong>
                <span className="x-small subtle">{fmtSize(f.size)} · Download</span>
              </span>
            </a>
          ) : null}
        </div>
      ))}
    </div>
  );
}

export function LinkPreview({
  preview,
  loading,
  onRemove,
}: {
  readonly preview: LinkPreviewData;
  readonly loading?: boolean | undefined;
  readonly onRemove?: (() => void) | undefined;
}) {
  if (loading) {
    return (
      <div className="og og--loading" aria-label="Fetching link preview">
        <div className="og__image" />
        <div className="og__body">
          <span className="og__site">Fetching preview</span>
          <span className="og__title">Loading the page title</span>
          <span className="og__desc">Reading Open Graph tags</span>
        </div>
      </div>
    );
  }
  return (
    <a className="og" href={preview.url} target="_blank" rel="noopener nofollow">
      <PreviewImage preview={preview} />
      <span className="og__body">
        <span className="og__site">{preview.site}</span>
        <span className="og__title">{preview.title}</span>
        {preview.desc ? <span className="og__desc">{preview.desc}</span> : null}
      </span>
      {onRemove ? (
        <IconButton
          size="tiny"
          variant="quiet"
          className="og__remove"
          aria-label="Remove preview"
          data-tip="Remove preview"
          data-tip-pos="top"
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            onRemove();
          }}
        >
          <Icon name="x" />
        </IconButton>
      ) : null}
    </a>
  );
}

// A site's image can be gone or blocked, so a letter tile stands in
function PreviewImage({ preview }: { readonly preview: LinkPreviewData }) {
  const [failed, setFailed] = useState(false);

  if (!preview.image || failed) {
    return <span className="og__image">{preview.site.charAt(0).toUpperCase()}</span>;
  }

  return (
    <img
      className="og__image og__image--photo"
      src={preview.image}
      loading="lazy"
      alt=""
      referrerPolicy="no-referrer"
      onError={() => setFailed(true)}
    />
  );
}
