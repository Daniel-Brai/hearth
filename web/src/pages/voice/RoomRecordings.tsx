import { useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import { Button } from '@/design-system';
import { useAppState } from '@/data/store';
import { RecordingList } from '@/features/recordings/RecordingList';
import { toRow } from '@/features/recordings/recording-row';

type RoomRecordingsProps = { readonly cid: string; readonly rid: string };

export function RoomRecordings({ cid, rid }: RoomRecordingsProps) {
  const gateway = useGateway();
  const [loading, setLoading] = useState(false);

  const { rows, more } = useAppState((state) => {
    const room = state.communities[cid]?.voice.find((v) => v.id === rid);

    const rows = Object.values(state.recordings)
      .filter((r) => r.c === cid && (r.rid ? r.rid === rid : r.room === room?.name))
      .reverse()
      .sort((a, b) => (b.startedAt ?? '').localeCompare(a.startedAt ?? ''))
      .map((r) => toRow(r));

    return { rows, more: Boolean(room?.recordingsAfter) };
  });

  const showMore = async () => {
    setLoading(true);

    try {
      await gateway.voice.moreRecordings(cid, rid);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="grid gap-2">
      <RecordingList
        id="voice-recordings"
        label="Recordings from this room"
        cid={cid}
        rows={rows}
      />
      {more ? (
        <Button
          id="voice-recordings-more"
          className="justify-self-center"
          disabled={loading}
          onClick={() => void showMore()}
        >
          {loading ? 'Loading' : 'Show older recordings'}
        </Button>
      ) : null}
    </div>
  );
}
