import type { AppState } from '@/domain/app-state';

export type Hydration = {
  readonly state: AppState;
  readonly loaded: readonly string[];
  readonly origin: string;
  readonly zone: string;
};

export const HYDRATION_KEY = '__HEARTH__';

// < and the line separators are escaped so post text can't close the script
export function hydrationScript(data: Hydration): string {
  const json = JSON.stringify(data)
    .replaceAll('<', '\\u003c')
    .replaceAll(' ', '\\u2028')
    .replaceAll(' ', '\\u2029');

  return `<script>window.${HYDRATION_KEY}=${json}</script>`;
}
