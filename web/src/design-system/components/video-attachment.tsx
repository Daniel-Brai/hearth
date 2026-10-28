import { lazy, Suspense, type CSSProperties } from 'react';
import { attachmentSrc, type Attachment } from '@/domain/types';

const VideoPlayer = lazy(() =>
  import('@/design-system/components/video-player').then((m) => ({ default: m.VideoPlayer })),
);

export function VideoAttachment({ file }: { readonly file: Attachment }) {
  const shape = (
    file.width && file.height ? { '--ratio': file.width / file.height } : undefined
  ) as CSSProperties | undefined;

  return (
    <div className="file-video" style={shape}>
      <Suspense fallback={<div className="file-video__placeholder" />}>
        <VideoPlayer
          src={attachmentSrc(file)}
          title={file.name}
          width={file.width}
          height={file.height}
          file={{ name: file.name, size: file.size }}
        />
      </Suspense>
    </div>
  );
}
