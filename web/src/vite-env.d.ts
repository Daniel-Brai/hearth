/// <reference types="vite/client" />
/// <reference types="vite-plugin-pwa/client" />

interface ImportMetaEnv {
  readonly VITE_HEARTH_DATA?: string;
  readonly VITE_API_URL?: string;
  readonly VITE_TRANSCRIPTION?: string;
}

/** Set at build time and commit is null outside a git checkout */
declare const __HEARTH_BUILD__: {
  readonly version: string;
  readonly commit: string | null;
  readonly builtAt: string;
};
