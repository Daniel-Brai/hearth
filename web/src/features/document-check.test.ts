import { describe, expect, it } from 'vitest';
import { shortFileName } from '@/domain/format';
import { isAllowedDocument } from '@/features/document-check';

const fileOf = (name: string, parts: BlobPart[]) => new File(parts, name);

function zipWith(entry: string): Uint8Array<ArrayBuffer> {
  const name = new TextEncoder().encode(entry);
  const local = new Uint8Array(30 + name.length);

  local.set([0x50, 0x4b, 0x03, 0x04]);
  local.set(name, 30);

  const central = new Uint8Array(46 + name.length);

  central.set([0x50, 0x4b, 0x01, 0x02]);
  central.set(name, 46);

  const end = new Uint8Array(22);

  end.set([0x50, 0x4b, 0x05, 0x06]);

  const out = new Uint8Array(local.length + central.length + end.length);

  out.set(local);
  out.set(central, local.length);
  out.set(end, local.length + central.length);

  return out;
}

describe('isAllowedDocument', () => {
  it('accepts real documents of each allowed type', async () => {
    expect(await isAllowedDocument(fileOf('spec.pdf', ['%PDF-1.7\n...']))).toBe(true);

    expect(await isAllowedDocument(fileOf('notes.docx', [zipWith('word/document.xml')]))).toBe(
      true,
    );

    expect(await isAllowedDocument(fileOf('budget.xlsx', [zipWith('xl/workbook.xml')]))).toBe(true);

    expect(await isAllowedDocument(fileOf('deck.pptx', [zipWith('ppt/presentation.xml')]))).toBe(
      true,
    );

    expect(await isAllowedDocument(fileOf('rows.csv', ['name,city\nAda,Lagos\n']))).toBe(true);
    expect(await isAllowedDocument(fileOf('readme.txt', ['Ẹ kú àárọ̀\n']))).toBe(true);
  });

  it('refuses other extensions', async () => {
    expect(await isAllowedDocument(fileOf('tool.exe', ['MZ']))).toBe(false);
    expect(await isAllowedDocument(fileOf('archive.zip', [zipWith('a.txt')]))).toBe(false);
    expect(await isAllowedDocument(fileOf('noextension', ['hello']))).toBe(false);
  });

  it('refuses a file whose contents do not match its name', async () => {
    expect(await isAllowedDocument(fileOf('invoice.pdf', ['MZ this is a program']))).toBe(false);
    expect(await isAllowedDocument(fileOf('notes.docx', [zipWith('xl/workbook.xml')]))).toBe(false);
    expect(await isAllowedDocument(fileOf('notes.docx', ['%PDF-1.7']))).toBe(false);

    expect(await isAllowedDocument(fileOf('data.csv', [Uint8Array.of(0x00, 0x01, 0x02)]))).toBe(
      false,
    );
  });
});

describe('shortFileName', () => {
  it('leaves short names alone', () => {
    expect(shortFileName('notes.pdf')).toBe('notes.pdf');
  });

  it('cuts long names in the middle and keeps the extension', () => {
    const short = shortFileName('Quarterly planning notes for the whole team.docx');
    expect(short.endsWith('….docx')).toBe(true);
    expect(short.length).toBeLessThanOrEqual(28);
  });

  it('cuts long names without an extension at the end', () => {
    expect(shortFileName('a'.repeat(40))).toBe('a'.repeat(27) + '…');
  });
});
