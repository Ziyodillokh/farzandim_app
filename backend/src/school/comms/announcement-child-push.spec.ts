import { Audience } from './comms.schemas';
import { announcementChildPush, childRecipientsWhere, RecipientRow, selectRecipients } from './announcement-child-push';

const audience = (over: Partial<Audience> = {}): Audience => ({
  kind: 'SCHOOL',
  classIds: [],
  guardianIds: [],
  includeStudents: true,
  ...over,
});

describe('childRecipientsWhere', () => {
  it('is null (no child pushes) when students are not included', () => {
    expect(childRecipientsWhere('s-1', audience({ includeStudents: false }))).toBeNull();
  });

  it('is null for a guardians-only audience even if the flag is set', () => {
    expect(childRecipientsWhere('s-1', audience({ kind: 'GUARDIANS', guardianIds: ['g-1'], includeStudents: true }))).toBeNull();
  });

  it('is null for a classes audience without classes', () => {
    expect(childRecipientsWhere('s-1', audience({ kind: 'CLASSES', classIds: [] }))).toBeNull();
  });

  it('targets only active, enrolled, app-linked students of the chosen classes', () => {
    const where = childRecipientsWhere('s-1', audience({ kind: 'CLASSES', classIds: ['c-5a', 'c-5b'] }));

    expect(where).toEqual({
      schoolId: 's-1',
      archived: false,
      classId: { in: ['c-5a', 'c-5b'] },
      childId: { not: null },
      child: { childUserId: { not: null } },
      school: { status: 'ACTIVE' },
    });
  });

  it('whole-school audience reaches every student that has a class', () => {
    const where = childRecipientsWhere('s-1', audience({ kind: 'SCHOOL' }));

    expect(where).toMatchObject({ schoolId: 's-1', archived: false, classId: { not: null }, childId: { not: null } });
  });
});

describe('selectRecipients', () => {
  const row = (over: Partial<RecipientRow> & { pref?: { schoolAnnouncements: boolean } | null } = {}): RecipientRow => ({
    childId: 'ch-1',
    child: { childUserId: 'cu-1', notificationPreference: over.pref ?? null },
    ...over,
  });

  it('keeps linked children when there is no preference row (announcements default to on)', () => {
    expect(selectRecipients([row()])).toEqual([{ childId: 'ch-1', childUserId: 'cu-1' }]);
  });

  it('skips children who switched school announcements off', () => {
    expect(selectRecipients([row({ pref: { schoolAnnouncements: false } })])).toEqual([]);
  });

  it('keeps children who left school announcements on', () => {
    expect(selectRecipients([row({ pref: { schoolAnnouncements: true } })])).toHaveLength(1);
  });

  it('skips students without a linked child or a child device account', () => {
    const unlinked: RecipientRow = { childId: null, child: null };
    const noDevice: RecipientRow = { childId: 'ch-2', child: { childUserId: null, notificationPreference: null } };

    expect(selectRecipients([unlinked, noDevice])).toEqual([]);
  });

  it('never returns the same child twice', () => {
    expect(selectRecipients([row(), row()])).toHaveLength(1);
  });
});

describe('announcementChildPush', () => {
  it('is ALWAYS neutral: no title, no body, no school — only the announcement id in data', () => {
    const push = announcementChildPush('uz', { id: 'ann-1' });

    expect(push).toEqual({
      title: 'Parvoz',
      body: 'Maktabdan yangi e\u02bclon',
      data: { type: 'SCHOOL_ANNOUNCEMENT', id: 'ann-1' },
    });
  });

  it('is neutral in Russian and English', () => {
    expect(announcementChildPush('ru', { id: 'a' }).body).toBe('Новое объявление школы');
    expect(announcementChildPush('en', { id: 'a' }).body).toBe('New announcement from school');
  });
});
