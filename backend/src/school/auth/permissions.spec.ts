import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { roleHas, SCHOOL_PERMISSIONS, SCHOOL_ROLES } from './permissions';

const PANEL_FILE = path.resolve(__dirname, '../../../../school-panel/src/auth/permissions.ts');

/** `care.settings` — Bola ovozi sozlamalarini yozish (mas'ul psixolog, o'rinbosar, ish vaqti, muddatlar). */
describe('care.settings permission', () => {
  it.each(['DIRECTOR', 'ADMIN', 'PSYCHOLOGIST'] as const)('is granted to %s', (role) => {
    expect(roleHas(role, 'care.settings')).toBe(true);
    expect(SCHOOL_ROLES[role].scope).toBe('SCHOOL');
  });

  it.each(['HOMEROOM', 'TEACHER', 'DUTY'] as const)('is NOT granted to %s', (role) => {
    expect(roleHas(role, 'care.settings')).toBe(false);
  });

  it('is part of the permission catalogue', () => {
    expect(SCHOOL_PERMISSIONS).toContain('care.settings');
  });

  it('does not make DIRECTOR / ADMIN protected roles (no access to children\'s content)', () => {
    expect(roleHas('DIRECTOR', 'care.individual')).toBe(false);
    expect(roleHas('ADMIN', 'care.individual')).toBe(false);
  });
});

/** Panel nusxasi (`school-panel/src/auth/permissions.ts`) bilan bir xil matritsa. */
(existsSync(PANEL_FILE) ? describe : describe.skip)('backend and panel permission matrices', () => {
  const source = existsSync(PANEL_FILE) ? readFileSync(PANEL_FILE, 'utf8') : '';
  const listAfter = (marker: string): string[] => {
    const from = source.indexOf(marker);
    const open = source.indexOf('[', from);
    const close = source.indexOf(']', open);
    return [...source.slice(open, close).matchAll(/'([^']+)'/g)].map((m) => m[1]!);
  };

  it('lists the same permission catalogue', () => {
    expect(listAfter('export const PERMISSIONS = ')).toEqual([...SCHOOL_PERMISSIONS]);
  });

  it.each(Object.keys(SCHOOL_ROLES))('grants %s the same permissions', (role) => {
    const roleBlock = source.slice(source.indexOf(`  ${role}: {`));
    const open = roleBlock.indexOf('permissions: [');
    const close = roleBlock.indexOf(']', open);
    const panel = [...roleBlock.slice(open, close).matchAll(/'([^']+)'/g)].map((m) => m[1]!);
    expect(panel).toEqual([...SCHOOL_ROLES[role as keyof typeof SCHOOL_ROLES].permissions]);
  });
});
