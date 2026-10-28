// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { parse } from 'yaml';
import { DEFAULT_PERMISSIONS } from '@/mocks/seed';
import { PERMISSIONS } from './permissions';
import source from '@apps/hearth/priv/permissions.yml?raw';

type Rule = {
  resource: string;
  operation: string;
  roles: string[];
  scope?: 'community' | 'instance';
};

/** Instance rules go to instance admins, never to a community's roles */
const rules = (parse(source) as Rule[]).filter((r) => r.scope !== 'instance');

/** The same naming the server uses, where dots inside the resource become dashes */
const permissionOf = (rule: Rule) => `${rule.resource.replaceAll('.', '-')}.${rule.operation}`;

const grantedTo = (role: string) =>
  rules
    .filter((r) => r.roles.includes(role))
    .map(permissionOf)
    .sort();

describe('permissions.yml', () => {
  it('produces exactly the permission strings the web app knows', () => {
    expect([...new Set(rules.map(permissionOf))].sort()).toEqual([...PERMISSIONS].sort());
  });

  it('gives the default roles what the in-memory gateway gives them', () => {
    expect(grantedTo('community.member')).toEqual([...DEFAULT_PERMISSIONS.member].sort());
    expect(grantedTo('community.moderator')).toEqual([...DEFAULT_PERMISSIONS.moderator].sort());
  });

  it('lets an owner do everything', () => {
    expect(grantedTo('community.owner')).toEqual([...PERMISSIONS].sort());
  });
});
