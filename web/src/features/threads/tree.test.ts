// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { buildForest, buildTree } from './tree';

type Item = { id: string; parent: string | null; who: string };

const item = (id: string, parent: string | null, who = 'a'): Item => ({ id, parent, who });
const who = (i: Item) => i.who;
const ids = (nodes: { item: Item }[]) => nodes.map((n) => n.item.id);

describe('buildForest', () => {
  it('nests replies under the one they answer and keeps oldest first', () => {
    const forest = buildForest(
      [item('a', null), item('b', 'a'), item('c', 'b'), item('d', 'a')],
      4,
      who,
    );

    const a = forest.get('a')!;

    expect(ids(a.children)).toEqual(['b', 'd']);
    expect(ids(a.children[0]!.children)).toEqual(['c']);
    expect(a.size).toBe(3);
  });

  it('places replies past the depth limit beside the one they answer', () => {
    const tree = buildTree(
      item('a', null),
      [item('b', 'a'), item('c', 'b'), item('d', 'c')],
      1,
      who,
    );

    expect(ids(tree.children)).toEqual(['b', 'c', 'd']);
  });

  it('says which reply a flattened reply answers', () => {
    const tree = buildTree(
      item('a', null),
      [item('b', 'a', 'bo'), item('c', 'b', 'cy'), item('d', 'c', 'di')],
      1,
      who,
    );

    const [b, c, d] = tree.children;

    expect(b!.answers).toBeNull();
    expect(c!.answers?.id).toBe('b');
    expect(d!.answers?.id).toBe('c');
  });

  it('collects up to three distinct authors under a branch', () => {
    const tree = buildTree(
      item('a', null, 'x'),
      [
        item('b', 'a', 'y'),
        item('c', 'b', 'z'),
        item('d', 'a', 'y'),
        item('e', 'a', 'w'),
        item('f', 'a', 'v'),
      ],
      4,
      who,
    );

    expect(tree.authors).toHaveLength(3);
    expect(new Set(tree.authors).size).toBe(3);
  });

  it('handles thousands of replies and a cycle without hanging', () => {
    const many = [item('r0', null)];

    for (let i = 1; i < 20000; i++) many.push(item('r' + i, 'r' + (i - 1)));
    many.push(item('x', 'y'), item('y', 'x'));

    const started = performance.now();
    const forest = buildForest(many, 4, who);

    expect(forest.get('r0')!.size).toBe(19999);
    expect(performance.now() - started).toBeLessThan(500);
  });
});
