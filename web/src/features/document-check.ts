import { DOCUMENT_EXTENSIONS } from '@/domain/catalog';
import { fileExtension } from '@/domain/format';

type DocumentExtension = (typeof DOCUMENT_EXTENSIONS)[number];

const OFFICE_PART: Partial<Record<DocumentExtension, string>> = {
  docx: 'word/document.xml',
  xlsx: 'xl/workbook.xml',
  pptx: 'ppt/presentation.xml',
};

/** The ZIP directory is in the last 64 KB plus its own record */
const ZIP_TAIL = 65_536 + 22;
const TEXT_SAMPLE = 8_192;

const isDocumentExtension = (ext: string | null): ext is DocumentExtension =>
  DOCUMENT_EXTENSIONS.some((d) => d === ext);

const ascii = (text: string) => new TextEncoder().encode(text);

function startsWith(bytes: Uint8Array, prefix: Uint8Array): boolean {
  return prefix.every((b, i) => bytes[i] === b);
}

function contains(bytes: Uint8Array, needle: Uint8Array): boolean {
  for (let i = 0; i <= bytes.length - needle.length; i++) {
    if (startsWith(bytes.subarray(i), needle)) return true;
  }

  return false;
}

const read = async (blob: Blob) => new Uint8Array(await blob.arrayBuffer());

async function looksLike(file: File, ext: DocumentExtension): Promise<boolean> {
  if (ext === 'pdf') return startsWith(await read(file.slice(0, 5)), ascii('%PDF-'));

  const part = OFFICE_PART[ext];

  if (part) {
    const head = await read(file.slice(0, 4));
    if (!startsWith(head, Uint8Array.of(0x50, 0x4b, 0x03, 0x04))) return false;

    return contains(await read(file.slice(Math.max(0, file.size - ZIP_TAIL))), ascii(part));
  }

  const sample = await read(file.slice(0, TEXT_SAMPLE));

  if (sample.includes(0)) return false;

  /* stream holds back a character the sample cuts in half */
  return !new TextDecoder('utf-8').decode(sample, { stream: true }).includes('�');
}

export async function isAllowedDocument(file: File): Promise<boolean> {
  const ext = fileExtension(file.name);
  if (!isDocumentExtension(ext)) return false;

  return looksLike(file, ext);
}
