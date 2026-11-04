import type { CSSProperties } from 'react';

const width = (inlineSize: string): CSSProperties => ({ inlineSize });

function Lines({ widths }: { readonly widths: readonly string[] }) {
  return (
    <div className="grid gap-2 flex-1 min-w-0">
      {widths.map((w, i) => (
        <span
          key={i}
          className={i === 0 ? 'skel skel--title' : 'skel skel--line'}
          style={width(w)}
        />
      ))}
    </div>
  );
}

function Field({ tall }: { readonly tall?: boolean | undefined }) {
  return (
    <div className="grid gap-2">
      <span className="skel skel--line" style={width('6rem')} />
      <span className={tall ? 'skel skel--field skel--area' : 'skel skel--field'} />
    </div>
  );
}

function SettingRow({ title }: { readonly title: string }) {
  return (
    <div className="skel-row">
      <Lines widths={[title, '70%']} />
      <span className="skel skel--switch" />
    </div>
  );
}

function FormBar() {
  return (
    <div className="flex justify-end gap-2">
      <span className="skel skel--btn" />
      <span className="skel skel--btn" />
    </div>
  );
}

export function VoiceShape() {
  return (
    <div className="grid gap-5">
      <div className="skel-card">
        <div className="skel-row">
          <span className="skel skel--tile" />
          <Lines widths={['55%']} />
        </div>
        <span className="skel skel--line" style={width('12rem')} />
        <span className="skel skel--line" style={width('75%')} />
      </div>
      <span className="skel skel--line" style={width('11rem')} />
      {[1, 2, 3].map((i) => (
        <div key={i} className="skel-card">
          <div className="skel-row">
            <span className="skel skel--thumb" />
            <Lines widths={['7rem', '11rem']} />
            <span className="skel skel--avatar" />
            <span className="skel skel--avatar" />
          </div>
        </div>
      ))}
    </div>
  );
}

export function EventsShape() {
  return (
    <div className="grid gap-4">
      <div className="skel-row">
        <span className="skel skel--btn" style={width('11rem')} />
        <span className="skel skel--line" style={width('6rem')} />
        <span className="flex-1" />
        <span className="skel skel--btn" style={width('9rem')} />
      </div>
      <span className="skel skel--line" style={width('5rem')} />
      {[70, 55, 62].map((w) => (
        <div key={w} className="skel-card">
          <div className="skel-row items-start">
            <span className="skel skel--tile" />
            <div className="grid gap-2 flex-1 min-w-0">
              <span className="skel skel--pill" />
              <span className="skel skel--title" style={width(`${w}%`)} />
              <span className="skel skel--line" style={width('50%')} />
              <div className="skel-row">
                <span className="skel skel--avatar" />
                <span className="skel skel--line" style={width('9rem')} />
              </div>
            </div>
            <span className="skel skel--btn" />
          </div>
        </div>
      ))}
    </div>
  );
}

export function FormShape() {
  return (
    <div className="grid gap-4">
      <div className="skel-card">
        <Field />
        <Field />
      </div>
      <div className="skel-card">
        <Field />
        <SettingRow title="9rem" />
        <Field tall />
      </div>
      <FormBar />
    </div>
  );
}

export function SettingsShape() {
  return (
    <div className="grid gap-4">
      {[
        ['7rem', '9rem'],
        ['8rem', '11rem', '10rem'],
        ['10rem', '8rem'],
      ].map((titles) => (
        <div key={titles.join()} className="skel-card">
          <span className="skel skel--title" style={width('7rem')} />
          {titles.map((title) => (
            <SettingRow key={title} title={title} />
          ))}
        </div>
      ))}
    </div>
  );
}

export function ListShape() {
  return (
    <div className="grid gap-4">
      <div className="skel-row">
        <span className="skel skel--field flex-1" />
        <span className="skel skel--field" style={width('9rem')} />
      </div>
      {[1, 2, 3, 4, 5, 6].map((i) => (
        <div key={i} className="skel-row">
          <span className="skel skel--avatar-md" />
          <Lines widths={[`${6 + (i % 3) * 2}rem`, '60%']} />
          <span className="skel skel--btn" />
        </div>
      ))}
    </div>
  );
}

export function RolesShape() {
  return (
    <div className="flex flex-wrap gap-4 items-start">
      <div className="grid gap-3" style={{ flex: '0 1 15rem' }}>
        <span className="skel skel--line" style={width('4rem')} />
        {[7, 5, 6, 8].map((w) => (
          <div key={w} className="skel-row">
            <span className="skel skel--dot" />
            <span className="skel skel--line" style={width(`${w}rem`)} />
          </div>
        ))}
        <span className="skel skel--field" />
      </div>
      <div className="skel-card" style={{ flex: '1 1 22rem' }}>
        <span className="skel skel--title" style={{ inlineSize: '9rem', blockSize: '1.8rem' }} />
        <span className="skel skel--line" style={width('4rem')} />
        <div className="flex gap-2">
          <span className="skel skel--pill" />
          <span className="skel skel--pill" />
          <span className="skel skel--pill" />
        </div>
        <span className="skel skel--line" style={width('8rem')} />
        {[9, 11, 8, 10, 12].map((w) => (
          <SettingRow key={w} title={`${w}rem`} />
        ))}
      </div>
    </div>
  );
}

export function CardsShape() {
  return (
    <div className="grid gap-3">
      {[1, 2, 3].map((i) => (
        <div key={i} className="skel-card">
          <div className="skel-row">
            <span className="skel skel--mark" />
            <Lines widths={[`${40 + i * 8}%`, '70%']} />
            <span className="skel skel--pill" />
          </div>
          <div className="skel-row skel-row--foot">
            <span className="skel skel--line" style={width('10rem')} />
            <span className="flex-1" />
            <span className="skel skel--btn" />
            <span className="skel skel--btn" />
          </div>
        </div>
      ))}
    </div>
  );
}

export function TranscriptShape() {
  return (
    <div className="grid gap-4">
      <div className="grid gap-3 justify-items-center" style={{ paddingBlock: '1rem' }}>
        <span className="skel skel--title" style={{ inlineSize: '70%', blockSize: '2.2rem' }} />
        <span className="skel skel--line" style={width('14rem')} />
        <span className="skel skel--btn" style={width('12rem')} />
      </div>
      <span className="skel skel--field" style={{ borderRadius: '99rem' }} />
      <div className="flex gap-2">
        <span className="skel skel--pill" />
        <span className="skel skel--pill" />
        <span className="skel skel--pill" />
      </div>
      {[90, 70, 85, 60, 80].map((w) => (
        <div key={w} className="skel-row items-start">
          <span className="skel skel--tiny" />
          <Lines widths={['5rem', `${w}%`]} />
        </div>
      ))}
    </div>
  );
}

export function CatchUpShape() {
  return (
    <div className="grid gap-4">
      {[1, 2].map((i) => (
        <div key={i} className="skel-card">
          <div className="skel-row">
            <span className="skel skel--mark" />
            <Lines widths={['9rem', '6rem']} />
            <span className="skel skel--btn" />
          </div>
          {[75, 60].map((w) => (
            <div key={w} className="skel-card">
              <span className="skel skel--pill" />
              <span className="skel skel--title" style={width(`${w}%`)} />
              <span className="skel skel--line" />
              <span className="skel skel--line" style={width('65%')} />
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

export function TemplatesShape() {
  return (
    <div className="grid gap-4">
      <span className="skel skel--line justify-self-center" style={width('70%')} />
      {[1, 4].map((rows) => (
        <div key={rows} className="skel-card">
          {Array.from({ length: rows }, (_, r) => (
            <div key={r} className="skel-row">
              <span className="skel skel--mark" />
              <Lines widths={[`${7 + r}rem`, '80%', '45%']} />
              <span className="skel skel--icon" />
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}
