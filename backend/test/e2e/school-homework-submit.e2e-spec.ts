// Yozma vazifa (bola tomoni): rasm bilan topshirish (magic bytes, limitlar, EXIF, idempotentlik,
// qayta yuborish, ruxsatlar) va imzolangan rasm proksisi.

import { resetDb } from './db';
import { at, DAY, seedWorld, setNow, World } from './school-attendance-fixtures';
import { InFlightGate } from '../../src/school/homework/homework-gate';
import { HomeworkSubmitService } from '../../src/school/homework/homework-submit.service';
import { signHomeworkPhoto } from '../../src/school/homework/homework-signature';
import { BUCKETS } from '../../src/common/storage/storage.constants';
import {
  appReq,
  createWritten,
  heic,
  jpeg,
  linkNewChild,
  memoryStorage,
  MemoryStorage,
  png,
  schoolReq,
  submitHomework,
  unlinkedChild,
  webp,
} from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';
import { TestChild } from './factories';

const REQUEST_A = '3f2c9a4e-8b1d-4c6f-9e0a-1b2c3d4e5f60';
const REQUEST_B = '7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const REQUEST_C = 'c0ffee00-1111-4222-8333-444455556666';
const bucketKeys = (storage: MemoryStorage) => [...storage.objects.keys()].filter((k) => k.startsWith(`${BUCKETS.schoolHomework}/`));

describe('School homework: topshirish va rasm proksisi', () => {
  let t: TestApp;
  let storage: MemoryStorage;
  let w: World;
  let bekChild: TestChild;

  beforeAll(async () => {
    storage = memoryStorage();
    t = await createTestApp({ storage });
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    storage.objects.clear();
    w = await seedWorld(t);
    setNow(t, at(DAY, '09:00'));
    bekChild = await linkNewChild(t, w.bek);
  });

  afterAll(() => t.close());

  const submit = (assignmentId: string, files: Parameters<typeof submitHomework>[3], fields: Record<string, string> = {}, token = w.child.token) =>
    submitHomework(t, token, assignmentId, files, fields);
  const list = (token = w.child.token) => appReq(t, token, 'GET', '/child/school/assignments');
  const fetchUrl = (url: string) => {
    const u = new URL(url);
    return t.app.inject({ method: 'GET', url: u.pathname + u.search });
  };

  describe('submission', () => {
    it('accepts 2 photos + comment: returns the submission with signed URLs, stores objects, strips EXIF', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);

      const res = await submit(a.id, [{ data: jpeg('one', 'GPS-41.31-69.24') }, { data: png(), filename: 'p.png', contentType: 'image/png' }], { comment: '  Tayyor  ' });

      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body).toMatchObject({ assignmentId: a.id, status: 'SUBMITTED', comment: 'Tayyor', reviewedAt: null, reviewNote: null });
      expect(body.photos).toHaveLength(2);
      expect(body.photos.map((p: { contentType: string; position: number }) => [p.position, p.contentType])).toEqual([
        [0, 'image/jpeg'],
        [1, 'image/png'],
      ]);
      expect(body.photos[0].url).toMatch(/\/api\/school\/homework\/photos\/[0-9a-f-]{36}\?exp=\d+&sig=/);
      expect(body.reviewedByStaffId).toBeUndefined();

      const keys = bucketKeys(storage);
      expect(keys).toHaveLength(2);
      expect(keys.every((k) => k.includes(`/homework/${w.schoolId}/${a.id}/${w.vali}/`))).toBe(true);
      const stored = [...storage.objects.values()].map((o) => o.body);
      expect(stored.some((b) => b.includes('GPS-41.31'))).toBe(false);
      expect(stored.every((b) => b.length > 0)).toBe(true);
    });

    it('accepts jpeg, png and webp by magic bytes (any declared type) and up to 5 files', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);

      const res = await submit(a.id, [
        { data: jpeg('a'), contentType: 'application/octet-stream', filename: 'x.bin' },
        { data: png() },
        { data: webp() },
        { data: png(), filename: 'IMG_1.PNG' },
        { data: jpeg('e'), field: 'photos' },
      ]);

      expect(res.statusCode).toBe(200);
      expect(res.json().photos.map((p: { contentType: string }) => p.contentType)).toEqual(['image/jpeg', 'image/png', 'image/webp', 'image/png', 'image/jpeg']);
      expect(bucketKeys(storage)).toHaveLength(5);
    });

    it('rejects no files, too many files, unsupported bytes, oversize files and bad fields without storing anything', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);

      expect((await submit(a.id, [])).json()).toMatchObject({ code: 'VALIDATION', message: 'files: errors.form.selectAtLeastOne' });
      const tooMany = await submit(a.id, Array.from({ length: 6 }, (_, i) => ({ data: jpeg(String(i)) })));
      expect(tooMany.statusCode).toBe(400);
      expect(tooMany.json()).toMatchObject({ code: 'VALIDATION', message: 'files: errors.form.tooMany' });
      expect((await submit(a.id, [{ data: Buffer.from('<html>hi</html>'), contentType: 'image/jpeg', filename: 'a.jpg' }])).statusCode).toBe(415);
      expect((await submit(a.id, [{ data: jpeg('ok') }, { data: Buffer.from('%PDF-1.7 not an image') }])).statusCode).toBe(415);
      expect((await submit(a.id, [{ data: Buffer.from('GIF89a.........') }])).statusCode).toBe(415);
      expect((await submit(a.id, [{ data: Buffer.alloc(0) }])).statusCode).toBe(415);
      // HEIC: EXIF/GPS'ni tozalay olmaymiz — rad etiladi; buzilgan JPEG ham (metadata qolib ketmasin).
      expect((await submit(a.id, [{ data: heic(), filename: 'IMG_1.HEIC', contentType: 'image/heic' }])).statusCode).toBe(415);
      expect((await submit(a.id, [{ data: jpeg('cut').subarray(0, 24) }])).statusCode).toBe(415);
      const big = Buffer.concat([jpeg('big'), Buffer.alloc(8 * 1024 * 1024)]);
      expect((await submit(a.id, [{ data: big }])).statusCode).toBe(413);
      expect((await submit(a.id, [{ data: jpeg('c') }], { comment: 'x'.repeat(1001) })).json()).toMatchObject({ message: 'comment: errors.form.tooLong' });
      expect((await submit(a.id, [{ data: jpeg('c') }], { requestId: 'not-a-uuid' })).statusCode).toBe(400);

      expect(bucketKeys(storage)).toHaveLength(0);
      expect(await t.prisma.schoolHomeworkSubmission.count()).toBe(0);
    });

    it('accepts a file of exactly 8 MB', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);
      const head = jpeg('exact');
      const exact = Buffer.concat([head, Buffer.alloc(8 * 1024 * 1024 - head.length)]);

      expect(exact.length).toBe(8 * 1024 * 1024);
      expect((await submit(a.id, [{ data: exact }])).statusCode).toBe(200);
    });

    it('refuses new uploads with 429 BUSY while too many are in flight, and recovers', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);
      const service = t.app.get(HomeworkSubmitService, { strict: false }) as unknown as { gate: InFlightGate };
      const original = service.gate;
      service.gate = new InFlightGate(0);

      try {
        const busy = await submit(a.id, [{ data: jpeg('x') }]);
        expect(busy.statusCode).toBe(429);
        expect(busy.json()).toMatchObject({ code: 'BUSY' });
        expect(await t.prisma.schoolHomeworkSubmission.count()).toBe(0);
      } finally {
        service.gate = original;
      }
      expect((await submit(a.id, [{ data: jpeg('x') }])).statusCode).toBe(200);
      expect(original.inFlight).toBe(0);
    });

    it('requires multipart', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);

      const res = await appReq(t, w.child.token, 'POST', `/child/school/assignments/${a.id}/submission`, { comment: 'x' });

      expect(res.statusCode).toBe(400);
    });

    it('is idempotent per requestId: same result, no duplicate rows or objects', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);

      const first = await submit(a.id, [{ data: jpeg('1') }, { data: jpeg('2') }], { requestId: REQUEST_A, comment: 'birinchi' });
      const retry = await submit(a.id, [{ data: jpeg('1') }, { data: jpeg('2') }], { requestId: REQUEST_A, comment: 'birinchi' });
      const differentBody = await submit(a.id, [{ data: jpeg('zzz') }], { requestId: REQUEST_A });

      expect(retry.statusCode).toBe(200);
      expect(retry.json()).toEqual(first.json());
      expect(differentBody.json()).toEqual(first.json());
      expect(await t.prisma.schoolHomeworkSubmission.count()).toBe(1);
      expect(await t.prisma.schoolHomeworkPhoto.count()).toBe(2);
      expect(bucketKeys(storage)).toHaveLength(2);
    });

    it('parallel identical requests do not duplicate or leak objects', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);

      const [r1, r2] = await Promise.all([
        submit(a.id, [{ data: jpeg('1') }, { data: jpeg('2') }], { requestId: REQUEST_A }),
        submit(a.id, [{ data: jpeg('1') }, { data: jpeg('2') }], { requestId: REQUEST_A }),
      ]);

      expect([r1.statusCode, r2.statusCode]).toEqual([200, 200]);
      expect(r1.json().id).toBe(r2.json().id);
      expect(await t.prisma.schoolHomeworkPhoto.count()).toBe(2);
      expect(bucketKeys(storage)).toHaveLength(2);
    });

    it('parallel different requests end with one consistent submission and no orphan objects', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);

      const results = await Promise.all([
        submit(a.id, [{ data: jpeg('1') }], { requestId: REQUEST_A }),
        submit(a.id, [{ data: jpeg('2') }, { data: jpeg('3') }], { requestId: REQUEST_B }),
      ]);

      expect(results.map((r) => r.statusCode)).toEqual([200, 200]);
      expect(await t.prisma.schoolHomeworkSubmission.count()).toBe(1);
      expect(bucketKeys(storage)).toHaveLength(await t.prisma.schoolHomeworkPhoto.count());
    });

    it('re-submission replaces photos and comment, resets review, deletes the old objects', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);
      const first = (await submit(a.id, [{ data: jpeg('old1') }, { data: jpeg('old2') }], { requestId: REQUEST_A, comment: 'eski' })).json();
      const oldKeys = bucketKeys(storage);
      expect((await schoolReq(t, w.admin, 'POST', `/learning/submissions/${first.id}/review`, { status: 'RETURNED', note: 'Aniqroq yozing' })).statusCode).toBe(200);

      const second = await submit(a.id, [{ data: jpeg('new') }], { requestId: REQUEST_B });

      expect(second.statusCode).toBe(200);
      expect(second.json()).toMatchObject({ id: first.id, status: 'SUBMITTED', comment: null, reviewedAt: null, reviewNote: null });
      expect(second.json().photos).toHaveLength(1);
      expect(second.json().photos[0].id).not.toBe(first.photos[0].id);
      const keys = bucketKeys(storage);
      expect(keys).toHaveLength(1);
      expect(oldKeys.some((k) => keys.includes(k))).toBe(false);
      expect(await t.prisma.schoolHomeworkPhoto.count()).toBe(1);
      expect(await t.prisma.schoolHomeworkSubmission.findUniqueOrThrow({ where: { id: first.id } })).toMatchObject({ reviewedByStaffId: null, requestId: REQUEST_B });
    });

    it('an ACCEPTED submission cannot be changed (409) but a replay of its requestId still returns it', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);
      const first = (await submit(a.id, [{ data: jpeg('1') }], { requestId: REQUEST_A })).json();
      await schoolReq(t, w.admin, 'POST', `/learning/submissions/${first.id}/review`, { status: 'ACCEPTED' });

      const blocked = await submit(a.id, [{ data: jpeg('2') }], { requestId: REQUEST_B });
      const replay = await submit(a.id, [{ data: jpeg('1') }], { requestId: REQUEST_A });

      expect(blocked.statusCode).toBe(409);
      expect(blocked.json()).toMatchObject({ code: 'ALREADY_ACCEPTED' });
      expect(replay.statusCode).toBe(200);
      expect(replay.json().id).toBe(first.id);
      expect(bucketKeys(storage)).toHaveLength(1);
    });

    it('only visible WRITTEN assignments: not TEST, not other class, not other school, not unknown', async () => {
      const other = await seedWorld(t, 'other-school');
      const test = (await schoolReq(t, w.admin, 'POST', '/learning/assignments', { materialId: 'test:MATH', classIds: [w.classA], dueDate: '2099-01-01' })).json();
      const otherClass = await createWritten(t, w.admin, [w.classB]);
      const foreign = await createWritten(t, other.admin, [other.classA]);

      for (const id of [test.id, otherClass.id, foreign.id, 'no-such-id']) {
        const res = await submit(id, [{ data: jpeg('x') }]);
        expect(res.statusCode).toBe(404);
      }
      expect(bucketKeys(storage)).toHaveLength(0);
    });

    it('hides assignments overdue by more than 7 days (same window as the list)', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);
      await t.prisma.schoolLearningAssignment.update({ where: { id: a.id }, data: { dueDate: '2000-01-01' } });

      expect((await submit(a.id, [{ data: jpeg('x') }])).statusCode).toBe(404);
      expect((await list()).json()).toEqual([]);
    });

    it('auth: parent token 403, anonymous 401, unlinked or archived child 404', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);

      expect((await submit(a.id, [{ data: jpeg('x') }], {}, w.parent.token)).statusCode).toBe(403);
      expect((await t.app.inject({ method: 'POST', url: `/api/child/school/assignments/${a.id}/submission` })).statusCode).toBe(401);

      const lonely = await unlinkedChild(t);
      const res = await submit(a.id, [{ data: jpeg('x') }], {}, lonely.token);
      expect(res.statusCode).toBe(404);
      expect(res.json()).toMatchObject({ code: 'NOT_ENROLLED' });

      await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: true } });
      expect((await submit(a.id, [{ data: jpeg('x') }])).statusCode).toBe(404);
    });

    it("two children submit to the same assignment independently", async () => {
      const a = await createWritten(t, w.admin, [w.classA, w.classB]);

      expect((await submit(a.id, [{ data: jpeg('vali') }])).statusCode).toBe(200);
      expect((await submit(a.id, [{ data: jpeg('bek') }, { data: jpeg('bek2') }], {}, bekChild.token)).statusCode).toBe(200);

      expect(await t.prisma.schoolHomeworkSubmission.count()).toBe(2);
      expect((await list()).json()[0].submission.photoCount).toBe(1);
      expect((await list(bekChild.token)).json()[0].submission.photoCount).toBe(2);
    });
  });

  describe('photo proxy (signed links)', () => {
    async function submitted() {
      const a = await createWritten(t, w.admin, [w.classA]);
      const body = (await submit(a.id, [{ data: jpeg('proxy-me', 'EXIF-SECRET') }, { data: png() }])).json();
      return { a, body, photos: body.photos as { id: string; url: string; contentType: string }[] };
    }

    it('serves the stored bytes with the right content type and private caching, without any token', async () => {
      const { photos } = await submitted();

      const res = await fetchUrl(photos[0].url);
      const png1 = await fetchUrl(photos[1].url);

      expect(res.statusCode).toBe(200);
      expect(res.headers['content-type']).toBe('image/jpeg');
      expect(String(res.headers['cache-control'])).toContain('private');
      expect(res.rawPayload.includes('proxy-me')).toBe(true);
      expect(res.rawPayload.includes('EXIF-SECRET')).toBe(false);
      expect(png1.headers['content-type']).toBe('image/png');
    });

    it('rejects tampered, missing, expired and foreign signatures with 403', async () => {
      const { photos } = await submitted();
      const u = new URL(photos[0].url);
      const base = u.pathname;
      const exp = u.searchParams.get('exp')!;
      const sig = u.searchParams.get('sig')!;
      const secret = process.env.JWT_ACCESS_SECRET!;
      const expired = Math.floor(Date.now() / 1000) - 10;
      const other = new URL(photos[1].url);

      const get = (qs: string) => t.app.inject({ method: 'GET', url: `${base}${qs}` });
      expect((await get('')).statusCode).toBe(403);
      expect((await get(`?exp=${exp}`)).statusCode).toBe(403);
      expect((await get(`?exp=${exp}&sig=${sig.slice(0, -2)}xx`)).statusCode).toBe(403);
      expect((await get(`?exp=${Number(exp) + 3600}&sig=${sig}`)).statusCode).toBe(403);
      expect((await get(`?exp=${expired}&sig=${signHomeworkPhoto(photos[0].id, expired, secret)}`)).statusCode).toBe(403);
      expect((await get(`?exp=${other.searchParams.get('exp')}&sig=${other.searchParams.get('sig')}`)).statusCode).toBe(403);
    });

    it('returns 404 for a valid signature on an unknown photo and when the object is gone', async () => {
      const { photos } = await submitted();
      const secret = process.env.JWT_ACCESS_SECRET!;
      const exp = Math.floor(Date.now() / 1000) + 600;
      const ghost = '00000000-0000-4000-8000-000000000000';

      const unknown = await t.app.inject({ method: 'GET', url: `/api/school/homework/photos/${ghost}?exp=${exp}&sig=${signHomeworkPhoto(ghost, exp, secret)}` });
      expect(unknown.statusCode).toBe(404);
      expect(unknown.headers['cache-control']).toBeUndefined(); // xato javobi keshlanmaydi

      storage.objects.clear();
      expect((await fetchUrl(photos[0].url)).statusCode).toBe(404);
    });

    it('answers 503 (not 404) when the storage itself fails', async () => {
      const { photos } = await submitted();
      const original = storage.getObject;
      storage.getObject = async () => {
        throw new Error('connect ETIMEDOUT');
      };

      try {
        expect((await fetchUrl(photos[0].url)).statusCode).toBe(503);
      } finally {
        storage.getObject = original;
      }
    });
  });
});
