// Multipart o'qish (Fastify `req.parts()`): 1-5 rasm (har biri <= 8 MB) + `comment`, `requestId`.
// Chegaralar so'rov darajasida (busboy) o'rnatiladi — katta fayl xotiraga to'liq o'qilmaydi.
// Format baytlardan aniqlanadi (`sniffImage`); EXIF/GPS olib tashlanadi — tozalab bo'lmaydigan
// (buzilgan) fayl rad etiladi. O'qish muddati cheklangan: sekin klient yuklash slotini band qilmasin.

import { PayloadTooLargeException, RequestTimeoutException, UnsupportedMediaTypeException } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { stripImageMetadataStrict } from '../../common/helpers/image-metadata';
import { invalid } from '../common/school-errors';
import { msg, parseOrThrow } from '../common/school-zod';
import { MAX_PHOTO_BYTES, MAX_PHOTOS, sniffImage, SniffedImage } from './homework-image';
import { SubmissionFields, submissionFieldsSchema } from './homework.schemas';

export interface UploadedPhoto extends SniffedImage {
  buffer: Buffer;
}

export interface HomeworkUpload {
  photos: UploadedPhoto[];
  fields: SubmissionFields;
}

interface Part {
  type: 'file' | 'field';
  fieldname: string;
  value?: unknown;
  toBuffer?: () => Promise<Buffer>;
}

interface MultipartCapable {
  raw?: { destroy: (error?: Error) => void };
  isMultipart?: () => boolean;
  parts?: (options: { limits: Record<string, number> }) => AsyncIterableIterator<Part>;
}

/** Matn maydonlari soni chegarasi (`comment`, `requestId` + zaxira). */
const MAX_FIELDS = 5;
const LIMITS = { fileSize: MAX_PHOTO_BYTES, files: MAX_PHOTOS, fields: MAX_FIELDS, parts: MAX_PHOTOS + MAX_FIELDS };
const MAX_FIELD_VALUE = 4000;
/** Butun multipart tanasini o'qish uchun muddat: 5 × 8 MB sekin mobil tarmoqda ham sig'adi. */
export const UPLOAD_DEADLINE_MS = 120_000;

const TOO_MANY = 'files: errors.form.tooMany';

function mapMultipartError(err: unknown): never {
  const code = (err as { code?: string } | null)?.code;
  if (code === 'FST_REQ_FILE_TOO_LARGE') {
    throw new PayloadTooLargeException({ code: 'FILE_TOO_LARGE', message: `Each photo must be at most ${MAX_PHOTO_BYTES / 1024 / 1024} MB` });
  }
  if (code === 'FST_FILES_LIMIT' || code === 'FST_PARTS_LIMIT' || code === 'FST_FIELDS_LIMIT') throw invalid(TOO_MANY);
  throw err;
}

async function readParts(req: MultipartCapable) {
  const buffers: Buffer[] = [];
  const raw: Record<string, string> = {};
  let timedOut = false;
  const deadline = setTimeout(() => {
    timedOut = true;
    req.raw?.destroy(new Error('Upload deadline exceeded'));
  }, UPLOAD_DEADLINE_MS);
  try {
    for await (const part of req.parts!({ limits: LIMITS })) {
      if (part.type === 'file') {
        buffers.push(await part.toBuffer!());
      } else if (typeof part.value === 'string') {
        raw[part.fieldname] = part.value.slice(0, MAX_FIELD_VALUE);
      }
    }
  } catch (err) {
    if (timedOut) throw new RequestTimeoutException({ code: 'UPLOAD_TIMEOUT', message: 'Upload took too long' });
    mapMultipartError(err);
  } finally {
    clearTimeout(deadline);
  }
  return { buffers, raw };
}

export async function readHomeworkUpload(req: FastifyRequest): Promise<HomeworkUpload> {
  const capable = req as unknown as MultipartCapable;
  if (typeof capable.parts !== 'function' || !capable.isMultipart?.()) throw invalid('files: errors.form.required');
  const { buffers, raw } = await readParts(capable);
  if (buffers.length === 0) throw invalid(`files: ${msg.atLeastOne}`);
  const unsupported = () => new UnsupportedMediaTypeException({ code: 'UNSUPPORTED_IMAGE', message: 'Only JPEG, PNG or WebP images are accepted' });
  const photos = buffers.map((buffer): UploadedPhoto => {
    const image = sniffImage(buffer);
    if (!image) throw unsupported();
    try {
      return { ...image, buffer: stripImageMetadataStrict(buffer) };
    } catch {
      throw unsupported(); // tuzilma buzilgan — metadata qolib ketishi mumkin
    }
  });
  return { photos, fields: parseOrThrow(submissionFieldsSchema, { comment: raw.comment, requestId: raw.requestId }) };
}
