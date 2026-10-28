export function secondsOf(t: string): number {
  return t.split(':').reduce((total, part) => total * 60 + (Number(part) || 0), 0);
}
