// Mirrors the server's permission enum
export const PERMISSIONS = [
  'post.create',
  'reply.create',
  'message.create',
  'voice-session.create',
  'voice-session.speak',
  'voice-recording.create',
  'community.update',
  'invite.create',
  'invite.update',
  'room.update',
  'room.delete',
  'event.create',
  'post.pin',
  'post.answer',
  'chat.promote',
  'content.remove',
  'member.ban',
  'role.update',
] as const;

export type Permission = (typeof PERMISSIONS)[number];
