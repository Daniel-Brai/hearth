// Stored keys like :tada: render from this map so the full picker data isn't needed
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const data = JSON.parse(
  readFileSync(require.resolve('@emoji-mart/data/sets/15/native.json'), 'utf8'),
);

const glyphs = {};
for (const [id, emoji] of Object.entries(data.emojis)) {
  const native = emoji.skins[0]?.native;
  if (native) glyphs[id] = native;
}

writeFileSync(
  new URL('../src/design-system/emoji/glyphs.json', import.meta.url),
  JSON.stringify(glyphs),
);
console.log(`${Object.keys(glyphs).length} emoji written`);
