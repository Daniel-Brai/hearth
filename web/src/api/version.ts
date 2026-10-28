// A date in a request header versions the API so paths stay the same
const API_VERSION_HEADER = 'Hearth-Version';
const API_VERSION = '2026-10-24';

export const apiHeaders = (hasBody: boolean): Record<string, string> => ({
  Accept: 'application/json',
  [API_VERSION_HEADER]: API_VERSION,
  ...(hasBody ? { 'Content-Type': 'application/json' } : {}),
});
