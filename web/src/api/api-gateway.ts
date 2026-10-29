import type { HearthGateway } from '@/data/gateway';
import type { Store } from '@/data/store';
import { createChatGateway } from './gateway/chat';
import { createCommunitiesGateway } from './gateway/communities';
import { GatewayContext } from './gateway/context';
import { createEventsGateway } from './gateway/events';
import { createInvitesGateway } from './gateway/invites';
import { createModerationGateway } from './gateway/moderation';
import { createNotificationsGateway } from './gateway/notifications';
import { createRoomsGateway } from './gateway/rooms';
import { createPeopleGateway } from './gateway/people';
import { createPostsGateway } from './gateway/posts';
import { createProfileGateway } from './gateway/profile';
import { createRolesGateway } from './gateway/roles';
import { createSessionGateway } from './gateway/session';
import { createSettingsGateway } from './gateway/settings';
import { createTranscriptsGateway } from './gateway/transcripts';
import { createVoiceGateway } from './gateway/voice';
import { reloadApp } from '@/runtime/reload';
import { routes } from '@/runtime/routes';

export class ApiGateway implements HearthGateway {
  readonly load: HearthGateway['load'];
  readonly session: HearthGateway['session'];
  readonly settings: HearthGateway['settings'];
  readonly profile: HearthGateway['profile'];
  readonly communities: HearthGateway['communities'];
  readonly rooms: HearthGateway['rooms'];
  readonly posts: HearthGateway['posts'];
  readonly chat: HearthGateway['chat'];
  readonly voice: HearthGateway['voice'];
  readonly events: HearthGateway['events'];
  readonly moderation: HearthGateway['moderation'];
  readonly roles: HearthGateway['roles'];
  readonly invites: HearthGateway['invites'];
  readonly notifications: HearthGateway['notifications'];

  constructor(store: Store) {
    const ctx = new GatewayContext(store);

    const notifications = createNotificationsGateway(ctx);
    const communities = createCommunitiesGateway(ctx);

    // The hooks run after sign in, once every part below exists
    const session = createSessionGateway(ctx, {
      onSignIn: () =>
        Promise.all([
          communities
            .loadJoined()
            .then(() =>
              Promise.all([
                moderation.loadCounts(),
                posts.loadDrafts(),
                chat.loadInbox(),
                voice.loadLive(),
              ]),
            ),
          notifications.load(),
          invites.load.myInvites(),
        ]),
      onNotice: (kind) => {
        void notifications.load();
        if (kind === 'invite') void invites.load.myInvites();
        if (kind === 'report') void moderation.loadCounts();
        if (kind === 'dm') void chat.loadInbox();
      },
      onSignOut: () => reloadApp(routes.signIn),
    });

    const posts = createPostsGateway(ctx);
    const { profile } = createProfileGateway(ctx);
    const { settings, load: settingsLoad } = createSettingsGateway(ctx);
    const roles = createRolesGateway(ctx, communities.load.community);
    const invites = createInvitesGateway(ctx, communities.load.community, roles.list);
    const people = createPeopleGateway(ctx, roles.list);
    const events = createEventsGateway(ctx, communities.load.community);
    const rooms = createRoomsGateway(ctx, communities.load.community);
    const chat = createChatGateway(ctx, communities.load.community, (key, topic) =>
      rooms.rooms.updateSettings(key, { topic }),
    );
    const moderation = createModerationGateway(ctx, communities.load.community);
    const voice = createVoiceGateway(ctx, communities.load.community);

    moderation.onRestoredMessage((key) => chat.load.chat(key));

    const transcripts = createTranscriptsGateway(ctx);

    this.load = {
      ...session.load,
      ...communities.load,
      ...posts.load,
      ...chat.load,
      ...invites.load,
      ...roles.load,
      ...people.load,
      ...events.load,
      ...rooms.load,
      ...moderation.load,
      ...voice.load,
      ...settingsLoad,
      ...transcripts.load,
    };

    this.session = {
      ...session.session,
      inviteByCode: invites.inviteByCode,
      acceptInvite: invites.acceptInvite,
    };

    this.communities = communities.communities;
    this.posts = posts.posts;
    this.chat = chat.chat;
    this.settings = settings;
    this.profile = profile;
    this.rooms = rooms.rooms;
    this.voice = { ...voice.voice, editTranscriptLine: transcripts.editLine };
    this.events = events.events;
    this.moderation = moderation.moderation;
    this.roles = roles.roles;
    this.invites = invites.invites;
    this.notifications = notifications.notifications;
  }
}
