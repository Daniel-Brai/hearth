import { describe, expect, it } from 'vitest';
import { withinAttachmentCap } from './composer-files';

const files = (n: number) =>
  Array.from({ length: n }, (_, i) => new File(['x'], `file-${i}.txt`, { type: 'text/plain' }));

describe('withinAttachmentCap', () => {
  it('keeps every file while there is room', () => {
    const chosen = files(3);

    expect(withinAttachmentCap(chosen, 2, 10)).toEqual({ kept: chosen, message: null });
  });

  it('keeps the earliest files and says how many were left out', () => {
    const chosen = files(13);
    const { kept, message } = withinAttachmentCap(chosen, 0, 10);

    expect(kept).toEqual(chosen.slice(0, 10));
    expect(message).toBe("You can attach up to 10 files at once. 3 weren't added.");
  });

  it('counts what is already attached', () => {
    const { kept, message } = withinAttachmentCap(files(1), 10, 10);

    expect(kept).toEqual([]);
    expect(message).toBe("You can attach up to 10 files at once. 1 wasn't added.");
  });
});
