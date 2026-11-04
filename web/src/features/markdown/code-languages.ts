/** The languages the code block menu offers. Each id is registered with the highlighter */
export const CODE_LANGUAGES = [
  { id: 'bash', label: 'Bash' },
  { id: 'c', label: 'C' },
  { id: 'cpp', label: 'C++' },
  { id: 'css', label: 'CSS' },
  { id: 'elixir', label: 'Elixir' },
  { id: 'go', label: 'Go' },
  { id: 'haskell', label: 'Haskell' },
  { id: 'html', label: 'HTML' },
  { id: 'javascript', label: 'JavaScript' },
  { id: 'json', label: 'JSON' },
  { id: 'python', label: 'Python' },
  { id: 'ruby', label: 'Ruby' },
  { id: 'rust', label: 'Rust' },
  { id: 'sql', label: 'SQL' },
  { id: 'typescript', label: 'TypeScript' },
  { id: 'yaml', label: 'YAML' },
] as const satisfies readonly { id: string; label: string }[];
