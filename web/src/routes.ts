import { index, layout, route, type RouteConfig } from '@react-router/dev/routes';
// Loaded before Vite's aliases apply so this import is relative
import { patterns, routes } from './runtime/routes';

const at = (file: string) => `app/routes/${file}.tsx`;

/**
 * Public screens render on the server for search engines and link previews
 * and the frames under standalone and protected render only in the browser
 */
export default [
  layout(at('standalone'), [
    route(routes.signIn, at('signin')),
    route(patterns.join, at('join')),
    route(routes.emailUndo, at('email-undo')),
  ]),
  layout(at('session'), [
    layout(at('public'), [
      index(at('home')),
      route(patterns.community, at('community'), { id: 'community' }),
      route(patterns.tag, at('community'), { id: 'tag' }),
      route(patterns.post, at('post')),
      route(patterns.communityEvents, at('events'), { id: 'community-events' }),
      route(patterns.event, at('events'), { id: 'event' }),
      route(patterns.profile, at('profile')),
      route(patterns.log, at('log')),
      route('*', at('not-found')),
    ]),
    layout(at('protected'), [
      route(patterns.chat, at('chat'), { id: 'chat' }),
      route(patterns.roomSettings, at('room-settings')),
      route(patterns.eventNew, at('schedule-event'), { id: 'event-new' }),
      route(patterns.eventEdit, at('schedule-event'), { id: 'event-edit' }),
      route(patterns.dm, at('chat'), { id: 'dm' }),
      route(patterns.voice, at('voice')),
      route(patterns.session, at('transcript')),
      route(patterns.communityNew, at('compose'), { id: 'community-compose' }),
      route(routes.newPost, at('compose'), { id: 'compose' }),
      route(routes.newCommunity, at('new-community')),
      route(patterns.communityEdit, at('edit-community')),
      route(patterns.invite, at('invite')),
      route(patterns.moderation, at('moderation')),
      route(patterns.roles, at('roles')),
      route(routes.events, at('events'), { id: 'events' }),
      route(routes.people, at('people')),
      route(routes.settings, at('settings')),
      route(routes.settingsProfile, at('edit-profile')),
      route(routes.settingsInstance, at('instance-settings')),
      route(routes.instanceReports, at('instance-reports')),
      route(routes.requests, at('requests')),
      route(routes.myInvites, at('my-invites')),
    ]),
  ]),
] satisfies RouteConfig;
