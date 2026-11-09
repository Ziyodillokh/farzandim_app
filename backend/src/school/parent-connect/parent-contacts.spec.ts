import { buildContacts, ContactStaff, contactGroup, snippet } from './parent-contacts';

const staff = (over: Partial<ContactStaff> & Pick<ContactStaff, 'id' | 'role'>): ContactStaff => ({
  fullName: `${over.id} F.I.Sh.`,
  position: '',
  active: true,
  hasAccount: true,
  classIds: [],
  ...over,
});

describe('contactGroup', () => {
  it('puts the class homeroom first, whatever the role', () => {
    expect(contactGroup(staff({ id: 'h', role: 'HOMEROOM' }), 'c1', 'h')).toBe('CLASS');
    expect(contactGroup(staff({ id: 'd', role: 'DIRECTOR' }), 'c1', 'd')).toBe('CLASS');
  });

  it('maps leadership, psychologists and the class teachers', () => {
    expect(contactGroup(staff({ id: 'd', role: 'DIRECTOR' }), 'c1', null)).toBe('LEADERSHIP');
    expect(contactGroup(staff({ id: 'a', role: 'ADMIN' }), 'c1', null)).toBe('LEADERSHIP');
    expect(contactGroup(staff({ id: 'p', role: 'PSYCHOLOGIST' }), 'c1', null)).toBe('SUPPORT');
    expect(contactGroup(staff({ id: 't', role: 'TEACHER', classIds: ['c1'] }), 'c1', null)).toBe('SUBJECT');
  });

  it('hides duty staff, other-class teachers, inactive staff and staff without a panel account', () => {
    expect(contactGroup(staff({ id: 'n', role: 'DUTY' }), 'c1', null)).toBeNull();
    expect(contactGroup(staff({ id: 't', role: 'TEACHER', classIds: ['c2'] }), 'c1', null)).toBeNull();
    expect(contactGroup(staff({ id: 'h2', role: 'HOMEROOM', classIds: [] }), 'c1', 'h1')).toBeNull();
    expect(contactGroup(staff({ id: 'd', role: 'DIRECTOR', active: false }), 'c1', null)).toBeNull();
    expect(contactGroup(staff({ id: 'd', role: 'DIRECTOR', hasAccount: false }), 'c1', null)).toBeNull();
  });

  it('shows only school-wide contacts to a student without a class', () => {
    expect(contactGroup(staff({ id: 't', role: 'TEACHER', classIds: ['c1'] }), null, null)).toBeNull();
    expect(contactGroup(staff({ id: 'd', role: 'DIRECTOR' }), null, null)).toBe('LEADERSHIP');
  });
});

describe('buildContacts', () => {
  it('orders groups (class, leadership, support, subject), director before admin, teachers by subject', () => {
    const contacts = buildContacts({
      classId: 'c1',
      homeroomStaffId: 'h',
      staff: [
        staff({ id: 't-math', role: 'TEACHER', position: 'Matematika', classIds: ['c1'] }),
        staff({ id: 'a', role: 'ADMIN' }),
        staff({ id: 'p', role: 'PSYCHOLOGIST' }),
        staff({ id: 't-eng', role: 'TEACHER', position: 'Ingliz tili', classIds: ['c1'] }),
        staff({ id: 'd', role: 'DIRECTOR' }),
        staff({ id: 'h', role: 'HOMEROOM', classIds: ['c1'] }),
      ],
      threads: new Map([['d', { threadId: 'th-1', unread: 2, lastMessageAt: new Date('2026-11-09T05:00:00Z') }]]),
    });
    expect(contacts.map((c) => c.staffId)).toEqual(['h', 'd', 'a', 'p', 't-eng', 't-math']);
    expect(contacts[1]).toMatchObject({ group: 'LEADERSHIP', threadId: 'th-1', unread: 2, lastMessageAt: '2026-11-09T05:00:00.000Z' });
    expect(contacts[0]).toMatchObject({ group: 'CLASS', threadId: null, unread: 0 });
  });
});

describe('snippet', () => {
  it('flattens whitespace and trims long text with an ellipsis', () => {
    expect(snippet('  Salom,\n\n ustoz  ')).toBe('Salom, ustoz');
    expect(snippet('a'.repeat(200), 10)).toBe(`${'a'.repeat(9)}…`);
  });
});
