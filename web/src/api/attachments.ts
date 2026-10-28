import type { Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { Attachment } from '@/domain/types';
import { dataUrlToBlob, uploadFile } from './upload';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const stored = (f: Attachment) => UUID.test(f.id);

async function blobOf(f: Attachment): Promise<Blob | null> {
  if (f.data !== undefined) return dataUrlToBlob(f.data);

  const read = await fetch(f.url);
  return read.ok ? read.blob() : null;
}

export async function sendFiles(
  files: readonly Attachment[],
  body: string,
): Promise<Result<{ ids: string[]; body: string }>> {
  const ids: string[] = [];
  let text = body;

  for (const f of files) {
    if (stored(f)) {
      ids.push(f.id);
      continue;
    }

    const blob = await blobOf(f);
    const media = blob && (await uploadFile(blob, f.name, 'attachment', f.durationMs));

    if (!media) return fail(`${f.name} didn't upload. Try again.`);

    ids.push(media.id);
    text = text.replaceAll(`attachment:${f.id}`, `attachment:${media.id}`);
  }

  return ok({ ids, body: text });
}
