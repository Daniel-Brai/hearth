import { uploadComplete, uploadCreate } from '@/generated/api/uploads/uploads';
import type { Media, RequestUploadBodyPurpose } from '@/generated/schemas';
import { call } from './gateway/context';

const toHex = (buffer: ArrayBuffer): string =>
  Array.from(new Uint8Array(buffer), (byte) => byte.toString(16).padStart(2, '0')).join('');

// Photos fit in one PUT and a file big enough for parts gets null
export async function uploadFile(
  file: Blob,
  name: string,
  purpose: RequestUploadBodyPurpose,
  durationMs?: number,
): Promise<Media | null> {
  const sha256 = toHex(await crypto.subtle.digest('SHA-256', await file.arrayBuffer()));

  const body = {
    name,
    content_type: file.type,
    byte_size: file.size,
    sha256,
    purpose,
    ...(durationMs === undefined ? {} : { duration_ms: durationMs }),
  };

  const headers = { 'Idempotency-Key': crypto.randomUUID() };

  const requested = await call(() => uploadCreate(body, { headers }));

  if (requested.status !== 201) return null;

  const { media, upload } = requested.data;

  if (!upload || !('url' in upload)) return null;

  const stored = await fetch(upload.url, { method: 'PUT', headers: upload.headers, body: file });

  if (!stored.ok) return null;

  const completed = await call(() => uploadComplete(media.id, {}));

  if (completed.status !== 200) return null;

  return completed.data;
}

export function dataUrlToBlob(dataUrl: string): Blob {
  const [header = '', data = ''] = dataUrl.split(',', 2);
  const type = header.slice('data:'.length).split(';')[0] ?? '';

  return new Blob([Uint8Array.from(atob(data), (char) => char.charCodeAt(0))], { type });
}
