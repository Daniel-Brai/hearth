import { ChoiceTiles, Field, Icon, Input, Segmented, Select } from '@/design-system';
import { DatePicker } from './DatePicker';
import { TimePicker } from './TimePicker';
import { DURATIONS, REPEATS, VOICE_MODES, voiceModeInfo } from './event-utils';
import type { ScheduleForm } from './use-schedule-form';

export function WhenFields({ form }: { readonly form: ScheduleForm }) {
  const { values, set } = form;

  return (
    <div className="form-grid">
      <Field label="Date" as="div">
        <DatePicker value={values.date} onChange={set.setDate} label="Date" futureOnly />
      </Field>
      <Field label="Starts at" as="div">
        <TimePicker value={values.time} onChange={set.setTime} label="Start time" />
      </Field>
      <Field label="Lasts" as="div">
        <Select
          block
          value={values.mins}
          options={DURATIONS}
          onChange={set.setMins}
          label="How long"
        />
      </Field>
    </div>
  );
}

export function WhereFields({ form }: { readonly form: ScheduleForm }) {
  const { values, set } = form;

  return (
    <>
      <Field label="Where" as="div">
        <ChoiceTiles
          name="ev-place"
          value={values.place}
          onChange={set.setPlace}
          label="Where it happens"
          tiles={[
            {
              value: 'hearth',
              icon: 'volume',
              label: 'Here on Hearth',
              sub: 'A voice or chat room',
            },
            {
              value: 'link',
              icon: 'video',
              label: 'Somewhere else',
              sub: 'A place, Meet, Zoom or a stream',
            },
          ]}
        />
      </Field>

      <div className="form-grid">
        {values.place === 'hearth' ? <RoomField form={form} /> : <LinkField form={form} />}

        <Field label="Repeats" as="div">
          <Select
            block
            value={values.repeat}
            options={REPEATS}
            onChange={set.setRepeat}
            label="Repeats"
          />
        </Field>
      </div>
    </>
  );
}

function RoomField({ form }: { readonly form: ScheduleForm }) {
  const { values, set, rooms } = form;

  return (
    <Field label="Room" as="div">
      {values.room ? (
        <Select block value={values.room} options={rooms} onChange={set.setRoom} label="Room" />
      ) : (
        <p className="small subtle m-0">
          This community has no voice or chat rooms yet. Use a link instead.
        </p>
      )}
    </Field>
  );
}

function LinkField({ form }: { readonly form: ScheduleForm }) {
  const { values, set, provider, problem } = form;

  return (
    <Field
      label="Link"
      hint={
        provider ? (
          <span className="icon-text">
            <Icon name={provider.known ? 'video' : 'external'} />
            <span>
              {provider.known ? `People join on ${provider.name}` : `Opens ${provider.host}`}
            </span>
          </span>
        ) : null
      }
    >
      <Input
        id="ev-url"
        type="url"
        inputMode="url"
        value={values.url}
        onChange={(e) => set.setUrl(e.target.value)}
        placeholder="A Google Maps place, or a Meet or Zoom link"
        shake={problem?.field === 'url'}
      />
    </Field>
  );
}

export function TalkField({ form }: { readonly form: ScheduleForm }) {
  const { values, set } = form;

  return (
    <Field label="Who can talk" as="div">
      <div className="flex items-center gap-3 flex-wrap">
        <Segmented
          name="ev-talk"
          value={values.talk}
          onChange={set.setTalk}
          label="Who can talk"
          options={VOICE_MODES.map((m) => ({
            value: m.id,
            label: (
              <>
                <Icon name={m.icon} />
                <span>{m.label}</span>
              </>
            ),
          }))}
        />
        <span className="field__hint m-0">{voiceModeInfo(values.talk).text}</span>
      </div>
    </Field>
  );
}
