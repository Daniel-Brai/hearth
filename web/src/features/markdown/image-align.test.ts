// @vitest-environment node
import { describe, expect, it } from 'vitest';
import {
  alignImageIn,
  attachmentHref,
  carouselIn,
  imageAlignIn,
  inCarouselIn,
  moveImageIn,
  removeImageFrom,
  splitImageHref,
} from './image-align';

const text = 'Before\n\n![sunset.png](attachment:a1)\n\nAfter';

describe('image alignment', () => {
  it('reads the alignment from the fragment, centred when there is none', () => {
    expect(splitImageHref('attachment:a1#left')).toEqual({ src: 'attachment:a1', align: 'left' });

    expect(splitImageHref('https://x.dev/p.png#top')).toEqual({
      src: 'https://x.dev/p.png#top',
      align: 'center',
    });

    expect(imageAlignIn(text, 'a1')).toBe('center');
    expect(imageAlignIn(text, 'a2')).toBeNull();
  });

  it('rewrites only the link and keeps the alt text', () => {
    const left = alignImageIn(text, 'a1', 'left');

    expect(left).toBe('Before\n\n![sunset.png](attachment:a1#left)\n\nAfter');
    expect(alignImageIn(left, 'a1', 'center')).toBe(text);
    expect(attachmentHref('a1', 'right')).toBe('attachment:a1#right');
  });

  it('does not match an id that only starts the same', () => {
    expect(imageAlignIn('![x](attachment:a10)', 'a1')).toBeNull();
  });

  it('takes the image out whatever its alignment, without leaving extra blank lines', () => {
    expect(removeImageFrom(alignImageIn(text, 'a1', 'right'), 'a1')).toBe('Before\n\nAfter');
  });
});

describe('moving an image', () => {
  const doc = 'Intro\n\n![a.png](attachment:a1#right)\n\nMiddle\n\nEnd';

  it('moves it to the end and keeps its alignment', () => {
    expect(moveImageIn(doc, 'a1', 'end')).toBe(
      'Intro\n\nMiddle\n\nEnd\n\n![a.png](attachment:a1#right)',
    );
  });

  it('moves it to a cursor position in the current text', () => {
    const at = doc.indexOf('End');

    expect(moveImageIn(doc, 'a1', at)).toBe(
      'Intro\n\nMiddle\n\n![a.png](attachment:a1#right)\n\nEnd',
    );
  });
});

describe('carousels', () => {
  const images = [
    { id: 'a1', name: 'a.png' },
    { id: 'a2', name: 'b.png' },
  ];

  const doc = 'Intro\n\n![a.png](attachment:a1)\n![b.png](attachment:a2)\n\nEnd';

  it('puts images together at the cursor', () => {
    const at = 'Intro\n\nEnd'.indexOf('End');

    expect(carouselIn('Intro\n\nEnd', images, at)).toBe(doc);
  });

  it('gathers images already in the text', () => {
    const text = '![a.png](attachment:a1)\n\nIntro\n\nEnd\n\n![b.png](attachment:a2#left)';

    expect(carouselIn(text, images, 'end')).toBe(
      'Intro\n\nEnd\n\n![a.png](attachment:a1)\n![b.png](attachment:a2)',
    );
  });

  it('keeps the first placed alignment', () => {
    expect(carouselIn('![b.png](attachment:a2#right)', images, 'end')).toBe(
      '![a.png](attachment:a1#right)\n![b.png](attachment:a2#right)',
    );
  });

  it('knows which images are in one', () => {
    expect(inCarouselIn(doc, 'a2')).toBe(true);
    expect(inCarouselIn(text, 'a1')).toBe(false);
  });

  it('aligns the whole carousel', () => {
    expect(alignImageIn(doc, 'a2', 'left')).toBe(
      'Intro\n\n![a.png](attachment:a1#left)\n![b.png](attachment:a2#left)\n\nEnd',
    );
  });

  it('moves the whole carousel', () => {
    expect(moveImageIn(doc, 'a1', 'end')).toBe(
      'Intro\n\nEnd\n\n![a.png](attachment:a1)\n![b.png](attachment:a2)',
    );
  });

  it('takes one image out and leaves the other in place', () => {
    expect(removeImageFrom(doc, 'a1')).toBe('Intro\n\n![b.png](attachment:a2)\n\nEnd');
  });
});
