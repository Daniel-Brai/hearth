import { decode, isBlurhashValid } from 'blurhash';

const WIDTH = 12;
const cache = new Map<string, string | null>();

/** A few pixels packed as a BMP so server and browser make the same string with no canvas and the browser smooths them into a blur */
export function blurUrl(hash: string, width?: number, height?: number): string | null {
  const ratio = width && height ? height / width : 1;
  const rows = Math.min(24, Math.max(4, Math.round(WIDTH * ratio)));
  const key = `${hash}:${rows}`;

  if (!cache.has(key))
    cache.set(
      key,
      isBlurhashValid(hash).result ? bmp(decode(hash, WIDTH, rows), WIDTH, rows) : null,
    );

  return cache.get(key) ?? null;
}

function bmp(rgba: Uint8ClampedArray, width: number, height: number): string {
  const stride = Math.ceil((width * 3) / 4) * 4;
  const size = 54 + stride * height;
  const bytes = new Uint8Array(size);
  const view = new DataView(bytes.buffer);

  bytes.set([0x42, 0x4d]);
  view.setUint32(2, size, true);
  view.setUint32(10, 54, true);
  view.setUint32(14, 40, true);
  view.setInt32(18, width, true);
  // A negative height stores rows top first as the decoder gives them
  view.setInt32(22, -height, true);
  view.setUint16(26, 1, true);
  view.setUint16(28, 24, true);

  for (let y = 0; y < height; y++)
    for (let x = 0; x < width; x++) {
      const from = (y * width + x) * 4;
      const to = 54 + y * stride + x * 3;

      bytes[to] = rgba[from + 2]!;
      bytes[to + 1] = rgba[from + 1]!;
      bytes[to + 2] = rgba[from]!;
    }

  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);

  return 'data:image/bmp;base64,' + btoa(binary);
}
