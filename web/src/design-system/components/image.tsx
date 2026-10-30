import type { CSSProperties } from 'react';
import { blurUrl } from './blur';
import { fadeIn } from './fade';

export type ImgProps = {
  readonly src: string;
  readonly alt: string;
  readonly width?: number | undefined;
  readonly height?: number | undefined;
  readonly lazy?: boolean | undefined;
  readonly className?: string | undefined;
  readonly blurhash?: string | undefined;
};

export function Img({ src, alt, width, height, lazy = true, className, blurhash }: ImgProps) {
  const blur = blurhash ? blurUrl(blurhash, width, height) : null;

  const style = {
    ...(width && height ? { aspectRatio: `${width} / ${height}` } : {}),
    ...(blur ? { '--blur': `url(${blur})` } : {}),
  } as CSSProperties;

  return (
    <img
      src={src}
      alt={alt}
      width={width}
      height={height}
      loading={lazy ? 'lazy' : 'eager'}
      decoding="async"
      {...fadeIn}
      data-blur={blur ? '' : undefined}
      className={className}
      style={style}
    />
  );
}
