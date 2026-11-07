import { describe, expect, it } from 'vitest';

import { coversWords, markMatches, searchWords } from './search';

describe('searchWords', () => {
  it('drops punctuation and repeats', () => {
    expect(searchWords('LiveView  form-recovery liveview?')).toEqual([
      'liveview',
      'form',
      'recovery',
    ]);
  });

  it('keeps at most eight', () => {
    expect(searchWords('a b c d e f g h i j')).toHaveLength(8);
  });
});

describe('coversWords', () => {
  it('needs every word', () => {
    expect(coversWords('Hydrating forms', ['hydr', 'tables'])).toBe(false);
  });

  it('matches the start of a word', () => {
    expect(coversWords('Hydrating forms', ['form', 'hydr'])).toBe(true);
  });
});

describe('markMatches', () => {
  it('marks words that start with a searched word', () => {
    expect(markMatches('Form recovery, forms', ['form'])).toEqual([
      { text: 'Form', hit: true, at: 0 },
      { text: ' ', hit: false, at: 4 },
      { text: 'recovery', hit: false, at: 5 },
      { text: ',', hit: false, at: 13 },
      { text: ' ', hit: false, at: 14 },
      { text: 'forms', hit: true, at: 15 },
    ]);
  });
});
