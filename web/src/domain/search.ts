const MOST_WORDS = 8;

const words = new Intl.Segmenter(undefined, { granularity: 'word' });

const tokens = (text: string) =>
  [...words.segment(text)].filter((s) => s.isWordLike).map((s) => s.segment.toLowerCase());

/** The words a search looks for split the way the server splits them */
export const searchWords = (query: string): string[] =>
  [...new Set(tokens(query))].slice(0, MOST_WORDS);

/** Every searched word starts a word somewhere in the text */
export const coversWords = (text: string, wanted: readonly string[]): boolean => {
  const found = tokens(text);

  return wanted.every((w) => found.some((t) => t.startsWith(w)));
};

export type MarkedPart = { readonly text: string; readonly hit: boolean; readonly at: number };

/** Splits text so the words that start with a searched word can be marked */
export const markMatches = (text: string, wanted: readonly string[]): MarkedPart[] =>
  [...words.segment(text)].map((s) => {
    const lower = s.segment.toLowerCase();

    return {
      text: s.segment,
      hit: !!s.isWordLike && wanted.some((w) => lower.startsWith(w)),
      at: s.index,
    };
  });
