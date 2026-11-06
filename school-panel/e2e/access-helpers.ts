import { expect, type Page } from '@playwright/test';

/** Mock baza (localStorage) — testlar o'quvchi va so'rovlarni shu yerdan topadi (seed holatiga qattiq bog'lanmaydi). */
type Db = {
  tables: {
    students: Array<{ id: string; classId: string; firstName: string; lastName: string; archived: boolean }>;
    classes: Array<{ id: string; name: string }>;
    audit: Array<{ action: string; module: string; entityId: string | null; params?: Record<string, string | number>; summary: string }>;
    notifications: Array<{ id: string; kind: string; roles: string[]; staffIds?: string[] }>;
    access: {
      linkedStudentIds: string[];
      credentials: Array<{ studentId: string; login: string }>;
      recoveryRequests: Array<{ id: string; studentId: string; status: string }>;
      linkRequests: Array<{ id: string; kind: string; studentId: string; childName: string; parentLinked: boolean; status: string }>;
      inviteCodes: Array<{ studentId: string; code: string; closedAt: string | null; studentUsedAt: string | null; studentConfirmedAt: string | null }>;
    };
  };
};

export type FoundStudent = { id: string; name: string; className: string };

export async function readDb(page: Page): Promise<Db> {
  const db = await page.evaluate(() => {
    const raw = localStorage.getItem('parvoz-school:db:v1');
    return raw ? (JSON.parse(raw) as unknown) : null;
  });
  expect(db).not.toBeNull();
  return db as Db;
}

export type StudentKind = 'unlinked' | 'linkedNoCredentials' | 'linkedWithCredentials' | 'openRecovery';

/** Berilgan holatdagi (va ixtiyoriy sinfdagi) birinchi o'quvchi. Tekshiruv kutayotganlar `unlinked` ga kirmaydi. */
export async function findStudent(page: Page, kind: StudentKind, classId?: string): Promise<FoundStudent> {
  const { tables } = await readDb(page);
  const { access } = tables;
  const linked = new Set(access.linkedStudentIds);
  const withCredentials = new Set(access.credentials.map((c) => c.studentId));
  const inReview = new Set(access.linkRequests.map((r) => r.studentId));
  const openRecovery = new Set(access.recoveryRequests.filter((r) => r.status === 'RECEIVED').map((r) => r.studentId));
  const matches = (id: string): boolean => {
    switch (kind) {
      case 'unlinked':
        return !linked.has(id) && !inReview.has(id);
      case 'linkedNoCredentials':
        return linked.has(id) && !withCredentials.has(id);
      case 'linkedWithCredentials':
        return withCredentials.has(id) && !openRecovery.has(id);
      case 'openRecovery':
        return openRecovery.has(id);
    }
  };
  const student = tables.students.find((s) => !s.archived && (!classId || s.classId === classId) && matches(s.id));
  expect(student, `${kind} ${classId ?? ''}`).toBeTruthy();
  const found = student as Db['tables']['students'][number];
  return { id: found.id, name: `${found.lastName} ${found.firstName}`, className: tables.classes.find((c) => c.id === found.classId)?.name ?? '' };
}

/** Barcha konsol xabarlari (parol logga tushmasligini tekshirish uchun). */
export function collectConsole(page: Page): string[] {
  const messages: string[] = [];
  page.on('console', (msg) => messages.push(msg.text()));
  page.on('pageerror', (err) => messages.push(err.message));
  return messages;
}

/** `window.print` ni soxtalashtiradi: chaqiruvlar sanaladi, brauzer oynasi ochilmaydi. */
export async function stubPrint(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const w = window as unknown as { __printCalls: number };
    w.__printCalls = 0;
    window.print = () => {
      w.__printCalls += 1;
    };
  });
}

export async function printCalls(page: Page): Promise<number> {
  return page.evaluate(() => (window as unknown as { __printCalls: number }).__printCalls);
}

/**
 * Boshqa brauzer tabi (bir xil localStorage) nomidan o'quvchini arxivga oladi — «oyna ochiq turganda boshqa xodim arxivladi» holati.
 * `storage` hodisasi asosiy tabda ko'rinishni yangilaydi (eskirgan oyna esa ochiq qoladi).
 */
export async function archiveStudentInOtherTab(page: Page, startUrl: string, studentId: string): Promise<void> {
  const other = await page.context().newPage();
  await other.goto(startUrl);
  await expect(other.locator('main h1').first()).toBeVisible();
  await other.evaluate((id) => {
    const key = 'parvoz-school:db:v1';
    const db = JSON.parse(localStorage.getItem(key) ?? '{}') as { tables: { students: Array<{ id: string; archived: boolean }> } };
    const student = db.tables.students.find((s) => s.id === id);
    if (student) student.archived = true;
    localStorage.setItem(key, JSON.stringify(db));
  }, studentId);
  await other.close();
  await expect.poll(async () => (await readDb(page)).tables.students.find((s) => s.id === studentId)?.archived).toBe(true);
}
