import { useState, type FormEvent } from 'react';
import { format } from 'date-fns';
import { useGateway } from '@/app/gateway-context';
import type { EventSpec } from '@/data/gateway';
import { useAppState } from '@/data/store';
import { voiceOn } from '@/domain/selectors';
import { evNext, evProvider } from '@/domain/events';
import type { CommunityEvent, EventRepeat, VoiceMode } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';
import { combine, dayKey } from './date-time';
import {
  flashText,
  alreadyPassed,
  initialPlace,
  initialRoom,
  resolveWhere,
  roomOptions,
  tomorrowAtFive,
  whenSummary,
  type Place,
  type Problem,
} from './schedule-form';

export function useScheduleForm(cid: string, event: CommunityEvent | null, onClose: () => void) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const community = useAppState((state) => state.communities[cid]);

  const voice = useAppState(voiceOn);
  const rooms = roomOptions(community, voice);
  const start = event ? evNext(event) : tomorrowAtFive();

  const [title, setTitle] = useState(event?.title ?? '');
  const [desc, setDesc] = useState(event?.desc ?? '');
  const [date, setDate] = useState(() => dayKey(start));
  const [time, setTime] = useState(() => format(start, 'HH:mm'));
  const [mins, setMins] = useState(String(event?.mins ?? 60));
  const [place, setPlace] = useState<Place>(() => initialPlace(event, rooms));
  const [room, setRoom] = useState(() => initialRoom(event, rooms));
  const [talk, setTalk] = useState<VoiceMode>(event?.talk ?? 'open');
  const [url, setUrl] = useState(event?.where.type === 'link' ? event.where.url : '');
  const [repeat, setRepeat] = useState<EventRepeat>(event?.repeat ?? 'none');
  const [notify, setNotify] = useState(!event);
  const [problem, setProblem] = useState<Problem | null>(null);

  const when = combine(date, time);

  const fail = (field: Problem['field'], text: string) => {
    setProblem({ field, text });
    window.setTimeout(() => setProblem((p) => (p ? { ...p, field: null } : p)), 450);
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setProblem(null);

    if (!title.trim()) return fail('title', 'Give the event a name');
    if (!when) return fail(null, 'Pick a date and time');
    if (!event && alreadyPassed(when)) return fail(null, 'That time has already passed');

    const resolved = resolveWhere(place, url, room);

    if ('problem' in resolved) return fail(resolved.problem.field, resolved.problem.text);

    const { where } = resolved;

    const spec: EventSpec = {
      title: title.trim(),
      desc: desc.trim(),
      start: when.toISOString(),
      mins: Number(mins),
      repeat,
      where,
      ...(where.type === 'voice' ? { talk } : {}),
      ...(event ? {} : { notify }),
    };

    const r = await gateway.events.save(cid, event?.id ?? null, spec);

    if (!r.ok) return fail(null, r.error);

    flash(flashText(event, notify, community?.name ?? 'the community'));
    onClose();
  };

  return {
    community,
    rooms,
    problem,
    submit,
    summary: whenSummary(when, mins, repeat),
    provider: url.trim() ? evProvider(url.trim()) : null,
    voice: place === 'hearth' && !!room?.startsWith('voice:'),
    values: { title, desc, date, time, mins, place, room, talk, url, repeat, notify },
    set: {
      setTitle,
      setDesc,
      setDate,
      setTime,
      setMins,
      setPlace,
      setRoom,
      setTalk,
      setUrl,
      setRepeat,
      setNotify,
    },
  };
}

export type ScheduleForm = ReturnType<typeof useScheduleForm>;
