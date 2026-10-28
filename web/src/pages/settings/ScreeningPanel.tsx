import { Panel, SettingsRow } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import type { ScreeningDay, ScreeningSummary } from '@/domain/types';
import './ScreeningPanel.css';

const COUNTS = ['screened', 'held', 'kept', 'removed'] as const;

const LABELS: Record<(typeof COUNTS)[number], string> = {
  screened: 'Screened',
  held: 'Held',
  kept: 'Kept',
  removed: 'Removed',
};

const SHOWN_DAYS = 14;

// Every day shown is within the last month, so the year adds nothing but width
const dayFormat = new Intl.DateTimeFormat('en-US', {
  month: 'short',
  day: 'numeric',
  timeZone: 'UTC',
});

const total = (days: readonly ScreeningDay[]) =>
  Object.fromEntries(
    COUNTS.map((key) => [key, days.reduce((sum, day) => sum + day[key], 0)]),
  ) as Record<(typeof COUNTS)[number], number>;

// Kept holds are screening's mistakes, so the advice follows how many of them there were
function advice(held: number, kept: number): string {
  if (held === 0) return 'Nothing was held.';
  if (kept * 2 > held)
    return 'People kept most holds, so screening holds too much. Raising the screening threshold in the server settings holds less.';
  if (kept * 5 > held)
    return `People kept ${kept} of ${held} holds. If that keeps up, raise the screening threshold in the server settings a little.`;

  return 'People kept few holds, so the threshold fits.';
}

export function ScreeningPanel() {
  const gateway = useGateway();
  const on = useAppState((state) => state.instance.aiScreening);

  useLoad(() => gateway.load.screening(), 'screening');

  const summary = useAppState((state) => state.instance.screening);

  if (!on || !summary) return null;

  return (
    <Panel className="grid" id="screening">
      <SettingsRow
        title="Screening"
        sub={`The last ${summary.period} days. Content scoring ${summary.threshold} or more waits for a person.`}
      />

      {summary.days.length ? (
        <ScreeningCounts summary={summary} />
      ) : (
        <p className="settings-row small subtle" id="screening-empty">
          Nothing was screened in the last {summary.period} days.
        </p>
      )}
    </Panel>
  );
}

function ScreeningCounts({ summary }: { readonly summary: ScreeningSummary }) {
  const sums = total(summary.days);

  return (
    <>
      <div className="settings-row screening-totals" id="screening-totals">
        {COUNTS.map((key) => (
          <div key={key} className="screening-total" data-warn={key === 'kept' && sums.kept > 0}>
            <strong>{sums[key]}</strong>
            <span>{LABELS[key]}</span>
          </div>
        ))}
      </div>

      <p className="settings-row small subtle" id="screening-advice">
        {advice(sums.held, sums.kept)}
      </p>

      <div className="settings-row screening-days-wrap">
        <table className="screening-days" id="screening-days">
          <thead>
            <tr>
              <th scope="col">Day</th>
              {COUNTS.map((key) => (
                <th key={key} scope="col">
                  {LABELS[key]}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {summary.days.slice(0, SHOWN_DAYS).map((day) => (
              <tr key={day.day}>
                <th scope="row">{dayFormat.format(new Date(day.day))}</th>
                {COUNTS.map((key) => (
                  <td key={key}>{day[key]}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
