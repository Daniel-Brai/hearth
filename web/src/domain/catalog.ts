import type {
  AttachmentKind,
  Category,
  Permission,
  PostKind,
  ReportReason,
  Template,
} from '@/domain/types';

const MB = 1024 * 1024;

export const UPLOAD_LIMITS = {
  image: 10 * MB,
  video: 100 * MB,
  file: 25 * MB,
} as const satisfies Record<AttachmentKind, number>;

export const DOCUMENT_EXTENSIONS = ['pdf', 'docx', 'xlsx', 'pptx', 'csv', 'txt'] as const;

export const VIDEO_MAX_SECONDS = 20 * 60;

export const REPORT_REASONS = [
  { value: 'spam', label: 'Spam or ads' },
  { value: 'harassment', label: 'Harassment or bullying' },
  { value: 'hate', label: 'Hate' },
  { value: 'sexual', label: 'Sexual content' },
  { value: 'violence', label: 'Violence or threats' },
  { value: 'off_topic', label: 'Off topic' },
  { value: 'other', label: 'Something else' },
] as const satisfies readonly { value: ReportReason; label: string }[];

export const TITLE_MAX = 150;

export const TITLE_LONG = 80;

export const MAX_ATTACHMENTS = 10;

export const SOUNDS: readonly string[] = [
  'tada',
  'rimshot',
  'trombone',
  'yodel',
  'crickets',
  'drama',
  'horn',
  '56k',
];

export const PERMS: readonly [key: Permission, label: string, description: string][] = [
  ['post.create', 'Start posts', 'Write new posts in the feed'],
  ['reply.create', 'Reply to posts', 'Join any thread'],
  ['message.create', 'Chat in rooms', 'Send messages in text rooms'],
  ['voice-session.create', 'Start voice rooms', 'Open a live room on any post'],
  ['voice-session.speak', 'Speak without asking', 'Skip the raise hand queue'],
  [
    'voice-recording.create',
    'Record and share screen',
    'Record live rooms and share a screen on stage',
  ],
  [
    'community.update',
    'Edit the community',
    'Change its name, look, links, visibility and moderation',
  ],
  ['invite.create', 'Share invite links', "Copy the community's invite link to share it"],
  ['invite.update', 'Manage invites', 'Change the link, email invites and see who was invited'],
  ['room.update', 'Manage rooms', 'Add, rename, archive and restore text and voice rooms'],
  ['room.delete', 'Delete rooms', 'Delete a room for good, with its messages and events'],
  ['event.create', 'Schedule events', 'Create, edit and cancel community events'],
  ['post.pin', 'Pin posts', 'Keep posts at the top of the feed'],
  ['post.answer', 'Mark answers', 'Stamp the reply that solved a question'],
  [
    'chat.promote',
    'Turn chat into posts',
    'Make a post from room messages, each under its own author',
  ],
  ['content.remove', 'Remove content', 'Take down posts and messages, logged publicly'],
  ['member.ban', 'Ban people', 'Ban accounts and add them to shared lists'],
  ['role.update', 'Manage roles', 'Create roles and change permissions'],
];

export const ROOM_DEFAULTS = {
  topic: '',
  previews: true,
  moderation: 'full',
  sounds: { enabled: true, mode: 'everyone', roles: [], people: [] },
};

// answers lets a reply be marked as the answer and mods limits posting to maintainers and moderators
const K = (
  name: string,
  icon: string,
  hue: string,
  hint: string,
  body: string,
  extra: Partial<PostKind> = {},
): PostKind => ({
  name,
  icon,
  hue,
  hint,
  body,
  answers: false,
  mods: false,
  desc: null,
  ...extra,
});

export const KIND_LIB = {
  question: K(
    'Question',
    'question',
    'blue',
    'What do you need help with?',
    'Say what you tried and what happened. Add photos or links if they help, @mention people and add #tags.',
    { answers: true, desc: 'Ask for help. Mark the reply that solved it.' },
  ),
  discussion: K(
    'Discussion',
    'chat',
    'violet',
    'What do you want to talk about?',
    'Write as much or as little as you like. Formatting, @mentions and #tags all work here.',
    { desc: 'Open ended talk, opinions and ideas.' },
  ),
  show: K(
    'Show and tell',
    'sparkles',
    'orange',
    'What did you make?',
    'Show it off. Add screenshots, a link and what you learned along the way.',
    { desc: 'Share something you built.' },
  ),
  announcement: K(
    'Announcement',
    'megaphone',
    'green',
    'What is the news?',
    'Releases, events and changes people should know about.',
    { mods: true, desc: 'News from the people who run it.' },
  ),
  proposal: K(
    'Proposal',
    'scroll',
    'pink',
    'What should change?',
    'Describe the problem, the proposed change and the alternatives you considered.',
    { desc: 'A request for comments on a change to the project.' },
  ),
  jobs: K(
    'Job',
    'briefcase',
    'yellow',
    'Who are you hiring?',
    'Role, location or remote, salary range and how to apply.',
    { desc: 'Share an open role on your team. Include pay and how to apply.' },
  ),
  bug: K(
    'Bug report',
    'bug',
    'red',
    'What went wrong?',
    'Steps to reproduce, what you expected, what happened instead, and your version.',
    { answers: true, desc: 'Something broken. Mark the reply with the fix.' },
  ),
  idea: K(
    'Idea',
    'bulb',
    'yellow',
    'What would make it better?',
    'Describe the problem first, then the idea. Mockups welcome.',
    { desc: 'Feature requests and suggestions.' },
  ),
  rec: K(
    'Recommendation',
    'star',
    'pink',
    'What should people read, watch or try?',
    'Say what it is, who it is for and why it stayed with you. No spoilers without a warning.',
    { desc: 'Something you think others will love.' },
  ),
  meetup: K(
    'Meetup',
    'calendar',
    'orange',
    'Where and when are you meeting?',
    'Place, time, what to bring and how people find you.',
    { desc: 'Plan a get together, online or in person.' },
  ),
  route: K(
    'Route',
    'map',
    'aqua',
    'Which route are you sharing?',
    'Distance, start point, surface, water stops and anything to watch out for.',
    { desc: 'A route people can run or ride.' },
  ),
  report: K(
    'Race report',
    'flag',
    'red',
    'How did it go?',
    'Your goal, how it went, what you would change next time.',
    { desc: 'Tell the story of an event you took part in.' },
  ),
  photo: K(
    'Photo',
    'image',
    'violet',
    'What did you capture?',
    'Paste or drop your photos, then say a bit about them.',
    { desc: 'Share pictures and the story behind them.' },
  ),
  intro: K(
    'Introduction',
    'users',
    'green',
    'Tell us about yourself',
    'Where you are, what brought you here and what you hope to get out of it.',
    { desc: 'Say hello when you are new.' },
  ),
} satisfies Record<string, PostKind>;

export type KindKey = keyof typeof KIND_LIB;

export const DEFAULT_KINDS: PostKind[] = (
  ['question', 'discussion', 'show', 'announcement'] as const
).map((k) => KIND_LIB[k]);

export const CATEGORIES: readonly Category[] = [
  { id: 'hobbies', label: 'Hobbies', icon: 'sparkles' },
  { id: 'games', label: 'Games', icon: 'shapes' },
  { id: 'art', label: 'Art and making', icon: 'image' },
  { id: 'music', label: 'Music', icon: 'music' },
  { id: 'books', label: 'Books and writing', icon: 'scroll' },
  { id: 'sports', label: 'Sports and fitness', icon: 'flame' },
  { id: 'local', label: 'Local groups', icon: 'map' },
  { id: 'learning', label: 'Learning', icon: 'bulb' },
  { id: 'work', label: 'Work and business', icon: 'briefcase' },
  { id: 'support', label: 'Support and care', icon: 'helpful' },
  { id: 'tech', label: 'Technology', icon: 'code' },
];

export const TEMPLATES: readonly Template[] = [
  {
    id: 'club',
    label: 'Club or hobby',
    icon: 'sparkles',
    desc: 'People who share an interest',
    category: 'hobbies',
    kinds: ['discussion', 'question', 'photo', 'meetup', 'announcement'],
    rooms: ['general', 'show-and-tell'],
    voice: 'Hangout',
    event: { title: 'First hangout', days: 7, mins: 60, repeat: 'none' },
    ph: { name: 'Plant Parents', tagline: 'Keeping houseplants alive together' },
  },
  {
    id: 'local',
    label: 'Local group',
    icon: 'map',
    desc: 'Neighbours, meetups and things to do nearby',
    category: 'local',
    kinds: ['meetup', 'question', 'discussion', 'intro', 'announcement'],
    rooms: ['general', 'events'],
    voice: 'Planning call',
    event: { title: 'First meetup planning call', days: 5, mins: 45, repeat: 'none' },
    ph: { name: 'Yaba Neighbours', tagline: 'News, events and help around Yaba' },
  },
  {
    id: 'creator',
    label: 'Creator and fans',
    icon: 'star',
    desc: 'A home for your audience',
    category: 'art',
    kinds: ['announcement', 'discussion', 'photo', 'question'],
    rooms: ['general', 'fan-art'],
    voice: 'Live hangout',
    event: { title: 'Live Q&A', days: 10, mins: 60, repeat: 'none' },
    ph: { name: 'Studio Ade', tagline: "Behind the scenes with Ade's comics" },
  },
  {
    id: 'class',
    label: 'Class or study group',
    icon: 'bulb',
    desc: 'Learn together, ask questions, share notes',
    category: 'learning',
    kinds: ['question', 'discussion', 'rec', 'announcement'],
    rooms: ['general', 'homework-help'],
    voice: 'Study room',
    event: { title: 'Weekly study session', days: 3, mins: 90, repeat: 'weekly' },
    ph: { name: 'Data Science Cohort 4', tagline: 'Notes, questions and study sessions' },
  },
  {
    id: 'support',
    label: 'Support group',
    icon: 'helpful',
    desc: 'A kind, moderated space to talk',
    category: 'support',
    kinds: ['intro', 'discussion', 'question', 'announcement'],
    rooms: ['general', 'small-wins'],
    voice: 'Check in',
    event: { title: 'Weekly check in', days: 6, mins: 60, repeat: 'weekly' },
    visibility: 'invite',
    ph: { name: 'New Parents Lagos', tagline: 'Sleepless and supported' },
  },
  {
    id: 'oss',
    label: 'Open source project',
    icon: 'code',
    desc: 'Help, ideas and releases for your project',
    category: 'tech',
    kinds: ['question', 'discussion', 'show', 'bug', 'idea', 'announcement'],
    rooms: ['general', 'help', 'contributors'],
    voice: 'Office hours',
    event: { title: 'Office hours', days: 7, mins: 60, repeat: 'weekly' },
    ph: { name: 'Feedbase', tagline: 'A self hosted RSS reader' },
  },
  {
    id: 'blank',
    label: 'Start from scratch',
    icon: 'plus',
    desc: 'Just a feed and #general',
    category: '',
    kinds: ['discussion', 'question', 'announcement'],
    rooms: ['general'],
    voice: null,
    event: null,
    ph: { name: 'Your community', tagline: 'What it is about, in a line' },
  },
];
