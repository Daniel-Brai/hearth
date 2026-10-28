export function keptForLater(transcribed: boolean, recorded: boolean, where: string): string {
  if (transcribed && recorded) return `The transcript and any recording are saved ${where}.`;
  if (transcribed) return `The transcript is saved ${where}.`;
  if (recorded) return `Any recording is saved ${where}.`;

  return '';
}

export function startNotice(canStart: boolean, member: boolean): string {
  if (canStart) return 'Start it and everyone else in this community gets a quiet notification.';
  if (member) return 'When it starts, you and everyone else here get a quiet notification.';

  return 'When it starts, members of this community get a quiet notification.';
}
