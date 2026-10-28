import type { CSSProperties } from 'react';
import { fadeIn } from './fade';

export type ImgProps = {
  readonly src: string;
  readonly alt: string;
  readonly width?: number | undefined;
  readonly height?: number | undefined;
  readonly lazy?: boolean | undefined;
  readonly className?: string | undefined;
};

export function Img({ src, alt, width, height, lazy = true, className }: ImgProps) {
  const style: CSSProperties | undefined =
    width && height ? { aspectRatio: `${width} / ${height}` } : undefined;

  return (
    <img
      src={src}
      alt={alt}
      width={width}
      height={height}
      loading={lazy ? 'lazy' : 'eager'}
      decoding="async"
      {...fadeIn}
      className={className}
      style={style}
    />
  );
}
