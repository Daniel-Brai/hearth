import { DOCUMENT_EXTENSIONS, UPLOAD_LIMITS, VIDEO_MAX_SECONDS } from '@/domain/catalog';
import { fmtLimit, shortFileName } from '@/domain/format';
import type { Attachment } from '@/domain/types';
import { isAllowedDocument } from '@/features/document-check';
import { resizeErrorText, resizeImage } from '@/features/images';
import { readVideoInfo } from '@/features/video';

let fileSeq = 0;

const DOCUMENTS_HINT = 'Documents can be PDF, Word, Excel, PowerPoint, CSV or text files.';

export const ACCEPT = ['image/*', 'video/*', ...DOCUMENT_EXTENSIONS.map((e) => '.' + e)].join(',');

function attachmentKind(mime: string): Attachment['kind'] {
  if (mime.startsWith('image/')) return 'image';
  if (mime.startsWith('video/')) return 'video';
  return 'file';
}

type Prepared = { ok: true; attachment: Attachment } | { ok: false; error: string };

async function prepareVideo(file: File, id: string): Promise<Prepared> {
  // react-doctor-disable-next-line react-doctor/no-create-object-url-without-revoke -- the preview lives as long as the attachment; Composer revokes it when the attachment is removed
  const url = URL.createObjectURL(file);
  const info = await readVideoInfo(url);

  if (info && Number.isFinite(info.duration) && info.duration > VIDEO_MAX_SECONDS) {
    URL.revokeObjectURL(url);
    return {
      ok: false,
      error: `${shortFileName(file.name)} is longer than ${VIDEO_MAX_SECONDS / 60} minutes. Trim it and try again.`,
    };
  }

  return {
    ok: true,
    attachment: {
      id,
      name: file.name,
      kind: 'video',
      size: file.size,
      url,
      ...(info ? { width: info.width, height: info.height } : {}),
      ...(info && Number.isFinite(info.duration)
        ? { durationMs: Math.max(1, Math.round(info.duration * 1000)) }
        : {}),
    },
  };
}

async function prepareImage(file: File, id: string): Promise<Prepared> {
  const r = await resizeImage(file, 1600, 1600);
  if (!r.ok) return { ok: false, error: resizeErrorText(r.error) };

  return {
    ok: true,
    attachment: {
      id,
      name: file.name,
      kind: 'image',
      size: file.size,
      data: r.dataUrl,
      width: r.width,
      height: r.height,
    },
  };
}

export async function prepareAttachment(file: File): Promise<Prepared> {
  const kind = attachmentKind(file.type);
  const id = 'f' + ++fileSeq;

  if (kind === 'file' && !(await isAllowedDocument(file))) {
    return { ok: false, error: `${shortFileName(file.name)} can't be attached. ${DOCUMENTS_HINT}` };
  }

  if (kind !== 'image' && file.size > UPLOAD_LIMITS[kind]) {
    const noun = kind === 'video' ? 'video' : 'file';
    return {
      ok: false,
      error: `${shortFileName(file.name)} is over ${fmtLimit(UPLOAD_LIMITS[kind])}, the most a ${noun} can be.`,
    };
  }

  if (kind === 'video') return prepareVideo(file, id);
  if (kind === 'image') return prepareImage(file, id);

  return {
    ok: true,
    // react-doctor-disable-next-line react-doctor/no-create-object-url-without-revoke -- the preview lives as long as the attachment; Composer revokes it when the attachment is removed
    attachment: { id, name: file.name, kind, size: file.size, url: URL.createObjectURL(file) },
  };
}

export type CapResult = { readonly kept: File[]; readonly message: string | null };

export function withinAttachmentCap(files: readonly File[], count: number, max: number): CapResult {
  const room = Math.max(max - count, 0);
  const kept = files.slice(0, room);
  const dropped = files.length - kept.length;

  if (dropped === 0) return { kept, message: null };

  const rest = dropped === 1 ? "1 wasn't added." : `${dropped} weren't added.`;

  return { kept, message: `You can attach up to ${max} files at once. ${rest}` };
}

export const paragraphGap = (text: string, edge: 'start' | 'end') => {
  if (!text) return '';
  const touching = edge === 'end' ? text.endsWith('\n') : text.startsWith('\n');
  return touching ? '' : '\n\n';
};
