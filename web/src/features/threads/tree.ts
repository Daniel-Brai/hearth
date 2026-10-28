export type Nestable = { readonly id: string; readonly parent?: string | null | undefined };

export type TreeNode<T> = {
  readonly item: T;
  readonly children: TreeNode<T>[];
  size: number;
  direct: number;
  readonly authors: string[];
  readonly answers: T | null;
};

const AUTHORS_SHOWN = 3;

type Placed<T> = { node: TreeNode<T>; depth: number; container: Placed<T> | null };

export function buildForest<T extends Nestable>(
  items: readonly T[],
  maxDepth: number,
  authorOf: (item: T) => string,
): Map<string, TreeNode<T>> {
  const ids = new Set(items.map((item) => item.id));
  const order = new Map(items.map((item, i) => [item.id, i]));
  const childrenOf = new Map<string, T[]>();
  const roots = new Map<string, TreeNode<T>>();
  const placed: Placed<T>[] = [];
  const stack: Placed<T>[] = [];

  for (const item of items) {
    if (item.parent && ids.has(item.parent) && item.parent !== item.id) {
      const siblings = childrenOf.get(item.parent);

      if (siblings) siblings.push(item);
      else childrenOf.set(item.parent, [item]);

      continue;
    }

    const top: Placed<T> = { node: newNode(item), depth: 0, container: null };

    roots.set(item.id, top.node);
    stack.push(top);
  }

  const seen = new Set<string>();

  while (stack.length) {
    const current = stack.pop()!;

    if (seen.has(current.node.item.id)) continue;
    seen.add(current.node.item.id);
    placed.push(current);
    current.node.direct = childrenOf.get(current.node.item.id)?.length ?? 0;

    const nests = current.depth < maxDepth || !current.container;
    const container = nests ? current : current.container!;
    const depth = nests ? current.depth + 1 : current.depth;

    const answers = nests ? null : current.node.item;

    for (const child of childrenOf.get(current.node.item.id) ?? []) {
      const entry: Placed<T> = { node: newNode(child, answers), depth, container };
      container.node.children.push(entry.node);
      stack.push(entry);
    }
  }

  for (let i = placed.length - 1; i >= 0; i--) {
    const { node, container } = placed[i]!;
    const indexOf = (n: TreeNode<T>) => order.get(n.item.id) ?? 0;

    if (node.children.length > 1) node.children.sort((a, b) => indexOf(a) - indexOf(b));
    if (!container) continue;

    container.node.size += node.size + 1;

    for (const who of [authorOf(node.item), ...node.authors]) {
      if (container.node.authors.length >= AUTHORS_SHOWN) break;
      // react-doctor-disable-next-line react-doctor/js-set-map-lookups -- the list holds at most AUTHORS_SHOWN people, so a Set would be slower
      if (!container.node.authors.includes(who)) container.node.authors.push(who);
    }
  }

  return roots;
}

export function buildTree<T extends Nestable>(
  root: T,
  replies: readonly T[],
  maxDepth: number,
  authorOf: (item: T) => string,
): TreeNode<T> {
  const tree = buildForest([{ ...root, parent: null }, ...replies], maxDepth, authorOf).get(
    root.id,
  );

  return tree ?? newNode(root);
}

function newNode<T>(item: T, answers: T | null = null): TreeNode<T> {
  return { item, children: [], size: 0, direct: 0, authors: [], answers };
}
