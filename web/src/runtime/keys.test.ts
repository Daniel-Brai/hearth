// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { assignKey, keyOf } from './keys';

describe('assignKey', () => {
  it('refuses keys the browser or text boxes own', () => {
    expect(assignKey('compose', 'mod+w', {})).toHaveProperty('error');
    expect(assignKey('compose', 'enter', {})).toHaveProperty('error');
  });

  it('swaps a clash onto the other action and reports it', () => {
    const result = assignKey('compose', 'n', {});

    if ('error' in result) throw new Error(result.error);

    expect(result.keys).toEqual({ compose: 'n', notifications: 'c' });
    expect(result.message).toContain('Notifications');
  });

  it("refuses a sequence that starts with another action's single key", () => {
    expect(assignKey('notifications', 'c h', {})).toHaveProperty('error');
  });

  it('drops a custom key that goes back to the default', () => {
    const result = assignKey('compose', 'c', { compose: 'x' });

    if ('error' in result) throw new Error(result.error);

    expect(result.keys).toEqual({});
    expect(keyOf('compose', result.keys)).toBe('c');
  });
});
