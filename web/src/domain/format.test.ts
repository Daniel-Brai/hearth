// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { typingLine } from './format';

describe('typingLine', () => {
  it('says nothing when nobody is typing', () => {
    expect(typingLine([])).toBeNull();
  });

  it('names up to three people', () => {
    expect(typingLine(['Bea'])).toBe('Bea is typing');
    expect(typingLine(['Bea', 'Remy'])).toBe('Bea and Remy are typing');
    expect(typingLine(['Bea', 'Remy', 'Mira'])).toBe('Bea, Remy and Mira are typing');
  });

  it('counts the rest past two names', () => {
    expect(typingLine(['Bea', 'Remy', 'Mira', 'Ada'])).toBe('Bea, Remy and 2 others are typing');
  });
});
