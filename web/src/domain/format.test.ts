// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { noun, typingLine } from './format';

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

describe('noun', () => {
  it('uses the singular for exactly one', () => {
    expect(noun(1, 'member')).toBe('member');
  });

  it('uses the plural otherwise', () => {
    expect(noun(0, 'member')).toBe('members');
    expect(noun(2, 'person', 'people')).toBe('people');
  });
});
