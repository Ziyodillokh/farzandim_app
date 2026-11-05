// Bola ilovasi maktab bo'limi (M01-M08) e2e fixture'lari: xotiradagi MinIO, multipart
// tanasi, kichik rasmlar (to'g'ri magic bytes), ikkinchi bola va xodim so'rovlari.

import type { SchoolStaffRole } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { createChild, createParent, TestChild } from './factories';
import { Session, World } from './school-attendance-fixtures';
import { TestApp } from './test-app';

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

// ─── Xotiradagi MinIO ───────────────────────────────────────────────

export interface MemoryObject {
  body: Buffer;
  contentType: string;
}

/** Soxta `StorageService`: yuklangan obyektlar `objects` da (`<bucket>/<key>`), `getObject` haqiqiy shaklda. */
export function memoryStorage() {
  const objects = new Map<string, MemoryObject>();
  const id = (bucket: string, key: string) => `${bucket}/${key}`;
  const noop = async () => undefined;
  return {
    objects,
    onModuleInit: noop,
    ensureBuckets: noop,
    getSignedUrl: async () => 'http://127.0.0.1:9/signed',
    upload: async (bucket: string, key: string, body: Buffer, contentType: string) => {
      objects.set(id(bucket, key), { body, contentType });
    },
    delete: async (bucket: string, key: string) => {
      objects.delete(id(bucket, key));
    },
    getObject: async (bucket: string, key: string) => {
      const found = objects.get(id(bucket, key));
      if (!found) throw new Error('NoSuchKey');
      return found;
    },
    getObjectStream: noop,
  };
}

export type MemoryStorage = ReturnType<typeof memoryStorage>;

// ─── Rasmlar (to'g'ri magic bytes, kichik) ──────────────────────────

/** JPEG; `exif` berilsa APP1 (EXIF) segmenti qo'shiladi — saqlashda olib tashlanishi kerak. */
export function jpeg(seed = 'a', exif?: string): Buffer {
  const app1 = exif ? Buffer.concat([Buffer.from([0xff, 0xe1]), u16(2 + 6 + exif.length), Buffer.from('Exif\0\0'), Buffer.from(exif)]) : Buffer.alloc(0);
  const app0 = Buffer.concat([Buffer.from([0xff, 0xe0, 0x00, 0x10]), Buffer.from('JFIF\0\x01\x01\0\0\x01\0\x01\0\0')]);
  return Buffer.concat([Buffer.from([0xff, 0xd8]), app0, app1, Buffer.from([0xff, 0xfe]), u16(2 + seed.length), Buffer.from(seed), Buffer.from([0xff, 0xd9])]);
}

export const png = (): Buffer =>
  Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk('IHDR', Buffer.alloc(13)), chunk('IEND', Buffer.alloc(0))]);

export const webp = (): Buffer => {
  const payload = Buffer.concat([Buffer.from('WEBP'), Buffer.from('VP8 '), le32(4), Buffer.alloc(4)]);
  return Buffer.concat([Buffer.from('RIFF'), le32(payload.length), payload]);
};

export const heic = (): Buffer => Buffer.concat([Buffer.from([0, 0, 0, 24]), Buffer.from('ftypheic'), Buffer.alloc(12)]);

function u16(n: number): Buffer {
  const b = Buffer.alloc(2);
  b.writeUInt16BE(n);
  return b;
}
function le32(n: number): Buffer {
  const b = Buffer.alloc(4);
  b.writeUInt32LE(n);
  return b;
}
function chunk(type: string, data: Buffer): Buffer {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  return Buffer.concat([len, Buffer.from(type), data, Buffer.alloc(4)]);
}

// ─── Multipart ──────────────────────────────────────────────────────

export interface FilePart {
  data: Buffer;
  filename?: string;
  contentType?: string;
  field?: string;
}

export function multipart(files: FilePart[], fields: Record<string, string> = {}) {
  const boundary = `----e2e${randomUUID()}`;
  const chunks: Buffer[] = [];
  for (const [name, value] of Object.entries(fields)) {
    chunks.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}\r\n`));
  }
  files.forEach((f, i) => {
    chunks.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="${f.field ?? 'files'}"; filename="${f.filename ?? `p${i}.jpg`}"\r\nContent-Type: ${f.contentType ?? 'image/jpeg'}\r\n\r\n`,
      ),
      f.data,
      Buffer.from('\r\n'),
    );
  });
  chunks.push(Buffer.from(`--${boundary}--\r\n`));
  return { payload: Buffer.concat(chunks), headers: { 'content-type': `multipart/form-data; boundary=${boundary}` } };
}

// ─── So'rovlar ──────────────────────────────────────────────────────

/** Xodim paneli so'rovi (`/api/school` + url), `Session` tokeni bilan. */
export function schoolReq(t: TestApp, s: Session, method: Method, url: string, payload?: object) {
  return t.app.inject({
    method,
    url: `/api/school${url}`,
    headers: { authorization: `Bearer ${s.token}` },
    ...(payload && { payload }),
  });
}

/** Bola / ota-ona ilovasi so'rovi (`/api` + url). */
export function appReq(t: TestApp, token: string, method: Method, url: string, payload?: object) {
  return t.app.inject({
    method,
    url: `/api${url}`,
    headers: { authorization: `Bearer ${token}` },
    ...(payload && { payload }),
  });
}

export function submitHomework(t: TestApp, token: string, assignmentId: string, files: FilePart[], fields: Record<string, string> = {}) {
  const { payload, headers } = multipart(files, fields);
  return t.app.inject({
    method: 'POST',
    url: `/api/child/school/assignments/${assignmentId}/submission`,
    headers: { authorization: `Bearer ${token}`, ...headers },
    payload,
  });
}

// ─── Dunyo ──────────────────────────────────────────────────────────

/** Mavjud o'quvchiga yangi ota-ona + bola (ilova) bog'lash. */
export async function linkNewChild(t: TestApp, studentId: string, name = 'Bola'): Promise<TestChild> {
  const parent = await createParent(t.prisma);
  const child = await createChild(t.prisma, parent, { name });
  await t.prisma.schoolStudent.update({ where: { id: studentId }, data: { childId: child.childId } });
  return child;
}

/** Bog'lanmagan bola (maktabga ulanmagan). */
export async function unlinkedChild(t: TestApp): Promise<TestChild> {
  return createChild(t.prisma, await createParent(t.prisma), { name: 'Yolg\'iz' });
}

export function staffOf(t: TestApp, w: World, role: SchoolStaffRole) {
  const map: Partial<Record<SchoolStaffRole, Session>> = {
    DIRECTOR: w.director,
    ADMIN: w.admin,
    HOMEROOM: w.homeroom,
    DUTY: w.duty,
    TEACHER: w.teacher,
    PSYCHOLOGIST: w.psych,
  };
  return map[role]!;
}

/** Yozma vazifa yaratish (xodim paneli orqali). */
export async function createWritten(t: TestApp, s: Session, classIds: string[], over: Record<string, unknown> = {}) {
  const res = await schoolReq(t, s, 'POST', '/learning/assignments', {
    materialId: 'written',
    title: 'Masala 5',
    estimatedMinutes: 30,
    classIds,
    dueDate: '2099-01-01',
    note: 'Daftarga yozing',
    ...over,
  });
  if (res.statusCode !== 201) throw new Error(`createWritten ${res.statusCode}: ${res.body}`);
  return res.json() as { id: string };
}
