import type { Boost } from '@/domain/types';

// The viewer's own reaction, added or taken back
export function setMine(holder: { boosts: Boost[] }, emoji: string, on: boolean) {
  const boost = holder.boosts.find((b) => b.e === emoji);

  if (!boost) {
    if (on) holder.boosts.push({ e: emoji, n: 1, mine: true });
    return;
  }

  if (boost.mine === on) return;

  boost.mine = on;
  boost.n += on ? 1 : -1;
  if (boost.n <= 0) holder.boosts.splice(holder.boosts.indexOf(boost), 1);
}

// Someone else's reaction, as the new count the server sent
export function setCount(holder: { boosts: Boost[] }, emoji: string, count: number) {
  const boost = holder.boosts.find((b) => b.e === emoji);

  if (count <= 0) holder.boosts = holder.boosts.filter((b) => b.e !== emoji);
  else if (boost) boost.n = count;
  else holder.boosts.push({ e: emoji, n: count, mine: false });
}
