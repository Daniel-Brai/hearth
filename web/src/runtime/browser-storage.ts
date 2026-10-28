// Node warns whenever its own storage globals are touched so server renders must not reach them
export const localStore = (): Storage | null =>
  typeof window === 'undefined' ? null : window.localStorage;

export const sessionStore = (): Storage | null =>
  typeof window === 'undefined' ? null : window.sessionStorage;
