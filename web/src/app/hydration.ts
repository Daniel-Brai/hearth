import type { AppState } from '@/domain/app-state';

export type Hydration = {
  readonly state: AppState;
  readonly loaded: readonly string[];
  readonly origin: string;
  readonly zone: string;
  readonly signedIn: boolean;
};

export const HYDRATION_KEY = '__HEARTH__';

// < and the line separators are escaped so post text can't close the script
export function scriptJson(value: unknown): string {
  return JSON.stringify(value)
    .replaceAll('<', '\\u003c')
    .replaceAll('\u2028', '\\u2028')
    .replaceAll('\u2029', '\\u2029');
}

export function hydrationScript(data: Hydration): string {
  return `<script>window.${HYDRATION_KEY}=${scriptJson(data)}</script>`;
}
