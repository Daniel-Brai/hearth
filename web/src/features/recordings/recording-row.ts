import { secondsOf } from '@/domain/clock';
import type { Recording, RecordingStatus } from '@/domain/types';

export type Row = {
  readonly id: string;
  readonly title: string;
  readonly by: string | null;
  readonly meta: string;
  readonly url: string | null;
  readonly download: string | null;
  readonly poster: string | null;
  readonly postId: string | null;
  readonly screen: boolean;
  readonly seconds: number;
  readonly status: RecordingStatus;
  readonly failure: string | null;
};

const metaOf = (parts: string[], screen: boolean) =>
  (screen ? [...parts, 'with screen share'] : parts).filter(Boolean).join(' · ');

export const toRow = (r: Recording, postId: string | null = r.postId || null): Row => ({
  id: r.id,
  title: r.title,
  by: r.by || null,
  meta: metaOf([r.date, r.duration], r.screen),
  url: r.url ?? null,
  download: r.download ?? r.url ?? null,
  poster: r.poster ?? null,
  postId,
  screen: r.screen,
  seconds: r.seconds ?? secondsOf(r.duration),
  status: r.status ?? 'ready',
  failure: r.failure ?? null,
});
