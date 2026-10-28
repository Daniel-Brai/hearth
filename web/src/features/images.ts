import { UPLOAD_LIMITS } from '@/domain/catalog';
import { fmtLimit } from '@/domain/format';

const MAX_IMAGE_BYTES = UPLOAD_LIMITS.image;

export type ResizeError = { kind: 'too-large' } | { kind: 'not-image' } | { kind: 'unreadable' };

export type ResizeResult =
  { ok: true; dataUrl: string; width: number; height: number } | { ok: false; error: ResizeError };

const readAsDataUrl = (blob: Blob) =>
  new Promise<string | null>((resolve) => {
    const reader = new FileReader();

    reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : null);
    reader.onerror = () => resolve(null);
    reader.readAsDataURL(blob);
  });

const encode = async (
  canvas: OffscreenCanvas | HTMLCanvasElement,
  type: string,
): Promise<Blob | null> => {
  if (canvas instanceof HTMLCanvasElement)
    return new Promise((resolve) => canvas.toBlob(resolve, type, 0.88));

  return canvas.convertToBlob({ type, quality: 0.88 });
};

export async function resizeImage(
  file: File,
  maxW: number,
  maxH: number,
  square = false,
): Promise<ResizeResult> {
  if (!file.type.startsWith('image/')) return { ok: false, error: { kind: 'not-image' } };
  if (file.size > MAX_IMAGE_BYTES) return { ok: false, error: { kind: 'too-large' } };

  let bitmap: ImageBitmap;

  try {
    bitmap = await createImageBitmap(file);
  } catch {
    return { ok: false, error: { kind: 'unreadable' } };
  }

  const side = Math.min(bitmap.width, bitmap.height);
  const sw = square ? side : bitmap.width;
  const sh = square ? side : bitmap.height;
  const scale = Math.min(1, maxW / sw, maxH / sh);
  const width = Math.round(sw * scale);
  const height = Math.round(sh * scale);

  const canvas =
    typeof OffscreenCanvas === 'undefined'
      ? Object.assign(document.createElement('canvas'), { width, height })
      : new OffscreenCanvas(width, height);

  const g = canvas.getContext('2d') as
    OffscreenCanvasRenderingContext2D | CanvasRenderingContext2D | null;

  if (!g) {
    bitmap.close();
    return { ok: false, error: { kind: 'unreadable' } };
  }

  const sx = square ? (bitmap.width - side) / 2 : 0;
  const sy = square ? (bitmap.height - side) / 2 : 0;

  g.drawImage(bitmap, sx, sy, sw, sh, 0, 0, width, height);
  bitmap.close();

  const blob = await encode(canvas, file.type === 'image/png' ? 'image/png' : 'image/jpeg');
  const dataUrl = blob ? await readAsDataUrl(blob) : null;

  if (!dataUrl) return { ok: false, error: { kind: 'unreadable' } };

  return { ok: true, dataUrl, width, height };
}

export const resizeErrorText = (e: ResizeError) => {
  switch (e.kind) {
    case 'too-large':
      return `That image is over ${fmtLimit(MAX_IMAGE_BYTES)}. Try a smaller one.`;
    case 'not-image':
      return 'That file is not an image.';
    case 'unreadable':
      return 'That image could not be read.';
  }
};
