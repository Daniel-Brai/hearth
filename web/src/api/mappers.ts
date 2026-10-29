import type {
  ChatMessage,
  Community as ApiCommunity,
  KindInput,
  CommunityTemplate,
  CommunityDetail,
  LinkPreview as ApiLinkPreview,
  Me,
  Media,
  Post as ApiPost,
  PostKind as ApiPostKind,
  Reply as ApiReply,
  Transcript as ApiTranscript,
  UserSummary,
  VoiceRecording,
} from '@/generated/schemas';
import type { Audience } from '@/domain/audience';
import { PERMISSIONS } from '@/domain/permissions';
import type {
  Attachment,
  Community,
  Hue,
  LinkPreview,
  Message,
  Permission,
  Person,
  Post,
  PostKind,
  Recording,
  Reply,
  Room,
  Template,
  Transcript,
  VoiceRoom,
} from '@/domain/types';

const HUES: readonly Hue[] = [
  'blue',
  'violet',
  'purple',
  'pink',
  'red',
  'orange',
  'yellow',
  'green',
  'aqua',
];

const KNOWN = new Set<string>(PERMISSIONS);
export const OPEN = new Set<string>(['public', 'public_indexed']);

const AUDIENCE = {
  public_indexed: 'indexed',
  public: 'public',
  invite_only: 'invite',
  private: 'private',
} as const satisfies Record<ApiCommunity['visibility'], Audience>;

export const SERVER_VISIBILITY = {
  indexed: 'public_indexed',
  public: 'public',
  invite: 'invite_only',
  private: 'private',
} as const satisfies Record<Audience, ApiCommunity['visibility']>;

export function hueOf(id: string): Hue {
  let sum = 0;
  for (const c of id) sum = (sum * 31 + c.charCodeAt(0)) % 9973;

  return HUES[sum % HUES.length]!;
}

export function ageOf(iso: string, now: number = Date.now()): string {
  const minutes = Math.floor((now - Date.parse(iso)) / 60_000);

  if (minutes < 1) return 'now';
  if (minutes < 60) return `${minutes}m`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)}h`;

  return `${Math.floor(minutes / 1440)}d`;
}

export const timeOf = (iso: string): string =>
  new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });

export const paragraphs = (markdown: string | null): string[] =>
  markdown === null ? [] : markdown.split('\n\n').filter((p) => p.trim() !== '');

const ownProfileOf = (user: UserSummary | Me): Partial<Person> => {
  if (!('privacy' in user)) return {};

  return {
    private: !user.privacy.show_name,
    links: user.links.map((link) => ({ url: link.url, label: link.label })),
    show: {
      presence: user.privacy.presence,
      photo: user.privacy.avatar,
      communities: user.privacy.show_communities,
    },
  };
};

export function toPerson(user: UserSummary | Me): Person {
  return {
    name: user.display_name ?? user.username,
    username: user.username,
    ...('email' in user ? { email: user.email } : {}),
    hue: hueOf(user.id),
    private: false,
    bio: 'bio' in user ? user.bio : null,
    pronouns: 'pronouns' in user ? user.pronouns : null,
    helped: 0,
    posts: 0,
    answers: 0,
    joined: null,
    location: 'location' in user ? user.location : null,
    photo: user.avatar_url,
    ...ownProfileOf(user),
  };
}

export const toKind = (kind: ApiPostKind): PostKind => ({
  key: kind.key,
  name: kind.label,
  icon: kind.icon,
  hue: kind.hue,
  hint: kind.title_hint ?? '',
  body: kind.body_hint ?? '',
  answers: kind.answers,
  mods: !kind.postable,
  desc: kind.description,
});

export const toKindInput = (kind: PostKind): KindInput => ({
  key: kind.key ?? null,
  label: kind.name.trim(),
  icon: kind.icon,
  hue: kind.hue,
  description: kind.desc,
  title_hint: kind.hint || null,
  body_hint: kind.body || null,
  answers: kind.answers,
  postable: !kind.mods,
});

const toPermissions = (permissions: readonly string[]): Permission[] =>
  permissions.filter((p): p is Permission => KNOWN.has(p));

const accessOf = (room: ApiCommunity['rooms'][number]) =>
  room.role_ids ? { access: room.access, roleIds: room.role_ids } : { access: room.access };

export function toCommunity(
  community: ApiCommunity,
  detail: CommunityDetail | null = null,
): Community {
  const rooms = community.rooms.filter((r) => r.archived_at === null);

  return {
    name: community.name,
    hue: community.hue,
    letter: community.name.charAt(0).toUpperCase(),
    logo: community.logo_url,
    banner: community.banner_url,
    tagline: community.tagline ?? '',
    intro: community.description,
    links: community.links.map((l) => ({ label: l.label ?? l.url, url: l.url })),
    members: community.member_count,
    online: community.online_count,
    joined: detail === null || detail.membership !== null,
    permissions: detail?.membership ? toPermissions(detail.membership.permissions) : [],
    visibility: OPEN.has(community.visibility) ? 'public' : 'invite',
    audience: AUDIENCE[community.visibility],
    indexed: community.visibility === 'public_indexed',
    maintainer: community.owner_id ?? '',
    welcome: community.welcome_message ?? '',
    rooms: rooms
      .filter((r) => r.type === 'text')
      .map((r): Room => ({ id: r.slug, name: r.name, unread: 0, ...accessOf(r) })),
    voice: rooms
      .filter((r) => r.type === 'voice')
      .map((r): VoiceRoom => ({
        id: r.slug,
        name: r.name,
        live: false,
        listeners: 0,
        topic: r.topic,
        host: '',
        postId: null,
        ...accessOf(r),
      })),
    summary: null,
    kinds: detail ? detail.kinds.map(toKind) : [],
    categories: community.categories,
    place: null,
    listed: community.visibility === 'public_indexed',
    verified: null,
    stats: { helpedWeek: 0, answered: 0, replyMins: 0, ageDays: 0 },
    moderation: community.moderation,
  };
}

export function toPost(post: ApiPost, c: string, kind: string, replies: Reply[] = []): Post {
  return {
    id: post.id,
    c,
    kind,
    title: post.title,
    author: post.author?.id ?? '',
    age: ageOf(post.inserted_at),
    at: post.inserted_at,
    seen: post.seen,
    pinned: post.pinned,
    watching: post.watching,
    tags: [],
    body: paragraphs(post.body),
    helpful: post.helpful_count,
    helpfulMine: false,
    boosts: post.reactions.map((r) => ({ e: r.emoji, n: r.count, mine: r.mine })),
    answer: post.answer_reply_id,
    fromChat: null,
    transcript: post.transcript?.session_id ?? null,
    replies,
    locked: post.locked,
    editedAt: post.edited_at,
    removed: post.status === 'removed',
    moderated: post.status === 'removed',
    pending: post.status === 'pending',
    reported: post.reported,
    inReview: post.in_review,
    replyCount: post.reply_count,
    files: toAttachments(post.attachments),
  };
}

export const toReply = (reply: ApiReply): Reply => ({
  id: reply.id,
  parent: reply.parent_reply_id,
  who: reply.author?.id ?? '',
  age: ageOf(reply.inserted_at),
  at: reply.inserted_at,
  helpful: reply.helpful_count,
  helpfulMine: false,
  body: paragraphs(reply.body),
  edited: reply.edited_at !== null,
  removed: reply.deleted || reply.status === 'removed',
  moderated: reply.status === 'removed',
  files: toAttachments(reply.attachments),
  answerCounts: { direct: reply.child_count, total: reply.descendant_count },
});

export const toLinkPreview = (preview: ApiLinkPreview): LinkPreview => ({
  url: preview.url,
  site: preview.site,
  title: preview.title,
  desc: preview.description,
  image: preview.image_url,
});

export const toMessage = (message: ChatMessage): Message => ({
  id: message.id,
  who: message.author?.id ?? '',
  text:
    message.status === 'removed' ? 'Removed by a moderator' : (message.body ?? 'Message deleted'),
  time: timeOf(message.inserted_at),
  boosts: message.reactions.map((r) => ({ e: r.emoji, n: r.count, mine: r.mine })),
  previewHidden: message.preview_hidden,
  parent: message.reply_to_id,
  edited: message.edited_at !== null,
  system: message.deleted || message.status === 'removed' || message.kind === 'promoted',
  moderated: message.status === 'removed',
  ...(message.kind === 'promoted' && message.post_id
    ? { promoted: { id: message.post_id, title: message.body ?? '' } }
    : {}),
  files: toAttachments(message.attachments),
  // Messages only count their direct answers
  answerCounts: { direct: message.child_count, total: message.child_count },
});

export const toTemplate = (template: CommunityTemplate): Template => ({
  id: template.id,
  label: template.label,
  icon: template.icon,
  desc: template.description,
  category: template.category ?? '',
  kinds: [...template.kinds],
  rooms: [...template.rooms],
  voice: template.voice,
  event: template.event,
  ph: template.placeholder,
});

const kindOf = (contentType: string): Attachment['kind'] => {
  if (contentType.startsWith('image/')) return 'image';
  if (contentType.startsWith('video/')) return 'video';
  return 'file';
};

function urlOf(media: Media): string | null {
  if (!media.urls) return null;

  const { original, variants } = media.urls;
  const kind = kindOf(media.content_type);
  const wanted = kind === 'video' ? 'mp4' : 'webp';

  const best = variants
    .filter((v) => v.format === wanted)
    .reduce<(typeof variants)[number] | null>((a, v) => (a && a.width >= v.width ? a : v), null);

  return kind === 'file' ? original : (best?.url ?? original);
}

function toAttachment(media: Media): Attachment | null {
  const url = urlOf(media);
  if (url === null) return null;

  return {
    id: media.id,
    name: media.name,
    kind: kindOf(media.content_type),
    size: media.byte_size,
    url,
    ...(media.urls ? { download: media.urls.download } : {}),
    ...(media.width === null ? {} : { width: media.width }),
    ...(media.height === null ? {} : { height: media.height }),
  };
}

export function toAttachments(
  media: readonly Media[],
  local: readonly Attachment[] = [],
): Attachment[] {
  return media.flatMap((m, i) => {
    const shown = toAttachment(m) ?? local[i];
    return shown ? [shown] : [];
  });
}

const DAY = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' });

const clock = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

export function toRecording(
  r: VoiceRecording,
  cid: string,
  rid: string,
  room: string,
  link: { postId?: string | undefined; eventId?: string | undefined } = {},
): Recording {
  const seconds = r.duration_ms === null ? undefined : Math.round(r.duration_ms / 1000);

  return {
    id: r.id,
    postId: link.postId ?? '',
    ...(link.eventId ? { eventId: link.eventId } : {}),
    c: cid,
    room,
    rid,
    title: r.title ?? room,
    duration: seconds === undefined ? '' : clock(seconds),
    date: DAY.format(new Date(r.started_at)),
    startedAt: r.started_at,
    by: r.started_by_id ?? '',
    screen: r.has_screen,
    real: true,
    ...(r.video_url ? { url: r.video_url } : {}),
    ...(r.download_url ? { download: r.download_url } : {}),
    status: r.status,
    failure: r.failure,
    poster: r.poster_url,
    ...(seconds === undefined ? {} : { seconds }),
    speakers: r.speakers.map((s) => ({ who: s.user_id, url: s.url })),
  };
}

export function toTranscript(t: ApiTranscript, cid: string): Transcript {
  const who = new Map(t.speakers.map((s) => [s.id, s.user_id ?? '']));
  const minutes = Math.max(1, Math.round((t.duration_ms ?? 0) / 60_000));

  return {
    id: t.session_id,
    postId: t.post_id ?? '',
    c: cid,
    room: t.room_name,
    title: t.topic ?? t.room_name,
    date: DAY.format(new Date(t.started_at)),
    duration: `${minutes} min`,
    speakers: t.speakers.flatMap((s) => (s.user_id ? [s.user_id] : [])),
    recording: t.recording.id,
    status: t.status,
    lines: t.segments.map((s) => ({
      id: s.id,
      who: who.get(s.speaker_id) ?? '',
      t: clock(Math.floor(s.start_ms / 1000)),
      text: s.text,
      editable: s.editable,
    })),
  };
}

// A post knows only the room and length, and the transcript page loads the rest
export function toTranscriptSummary(post: ApiPost, cid: string): Transcript | null {
  if (!post.transcript) return null;

  const minutes = Math.max(1, Math.round((post.transcript.duration_ms ?? 0) / 60_000));

  return {
    id: post.transcript.session_id,
    postId: post.id,
    c: cid,
    room: post.transcript.room_name,
    title: post.title,
    date: '',
    duration: `${minutes} min`,
    speakers: [],
    recording: null,
    lines: [],
    status: 'ready',
  };
}
