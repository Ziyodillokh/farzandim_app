import { Audience } from './comms.schemas';
import {
  announcementChildPush,
  ANNOUNCEMENT_PUSH_TITLE_MAX,
  childRecipientsWhere,
  RecipientRow,
  selectRecipients,
  truncateTitle,
} from './announcement-child-push';

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
  const row = (over: Partial<RecipientRow> & { pref?: { schoolAnnouncements: boolean; hideText: boolean } | null } = {}): RecipientRow => ({
    childId: 'ch-1',
    child: { childUserId: 'cu-1', notificationPreference: over.pref ?? null },
    ...over,
  });

  it('keeps linked children and defaults to hidden text when there is no preference row', () => {
    expect(selectRecipients([row()])).toEqual([{ childId: 'ch-1', childUserId: 'cu-1', hideText: true }]);
  });

  it('skips children who switched school announcements off', () => {
    expect(selectRecipients([row({ pref: { schoolAnnouncements: false, hideText: true } })])).toEqual([]);
  });

  it('carries the hideText preference through', () => {
    const [r] = selectRecipients([row({ pref: { schoolAnnouncements: true, hideText: false } })]);

    expect(r?.hideText).toBe(false);
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

describe('truncateTitle', () => {
  it('keeps short titles as they are (whitespace normalised)', () => {
    expect(truncateTitle('  Ota-onalar   yig\'ilishi ')).toBe("Ota-onalar yig'ilishi");
  });

  it('never exceeds 80 characters and ends with an ellipsis when cut', () => {
    const cut = truncateTitle('A'.repeat(200));

    expect([...cut]).toHaveLength(ANNOUNCEMENT_PUSH_TITLE_MAX);
    expect(cut.endsWith('…')).toBe(true);
  });

  it('keeps an 80 character title untouched', () => {
    const exact = 'B'.repeat(ANNOUNCEMENT_PUSH_TITLE_MAX);

    expect(truncateTitle(exact)).toBe(exact);
  });

  it('does not cut an emoji in half', () => {
    const cut = truncateTitle('📚'.repeat(100));

    // Yolg'iz surrogat bo'lsa UTF-8 aylanishi uni almashtirib yuboradi.
    expect(Buffer.from(cut, 'utf8').toString('utf8')).toBe(cut);
    expect([...cut]).toHaveLength(ANNOUNCEMENT_PUSH_TITLE_MAX);
  });
});

describe('announcementChildPush', () => {
  const a = { id: 'ann-1', school: '5-maktab', title: "Ertaga dars 9:00 da boshlanadi" };

  it('is neutral when text is hidden: no title, no school', () => {
    const push = announcementChildPush('uz', { ...a, hideText: true });

    expect(push).toEqual({
      title: 'Parvoz',
      body: 'Maktabdan yangi eʼlon',
      data: { type: 'SCHOOL_ANNOUNCEMENT', id: 'ann-1' },
    });
    expect(JSON.stringify(push)).not.toContain('dars');
    expect(JSON.stringify(push)).not.toContain('5-maktab');
  });

  it('is neutral in Russian', () => {
    expect(announcementChildPush('ru', { ...a, hideText: true }).body).toBe('Новое объявление школы');
  });

  it('shows the school and the announcement title (not the body) when text is not hidden', () => {
    const push = announcementChildPush('uz', { ...a, hideText: false });

    expect(push.title).toBe('5-maktab');
    expect(push.body).toBe('Ertaga dars 9:00 da boshlanadi');
    expect(push.data).toEqual({ type: 'SCHOOL_ANNOUNCEMENT', id: 'ann-1' });
  });

  it('falls back to the neutral title when the school has no name', () => {
    expect(announcementChildPush('uz', { ...a, school: '', hideText: false }).title).toBe('Parvoz');
  });
});
