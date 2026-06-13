import { BadRequestException, PayloadTooLargeException } from '@nestjs/common';
import { FastifyRequest } from 'fastify';

/** Yuklangan fayl — service'lar kutadigan Multer-mos shakl. */
export interface UploadedPart {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
}

export interface ParsedMultipart {
  files: Record<string, UploadedPart>;
  fields: Record<string, string>;
}

/**
 * `@fastify/multipart` oqimini o'qib, fayllar (buffer) va matn maydonlarni
 * qaytaradi.
 *
 * Nega kerak: `FileFieldsInterceptor` (`@nestjs/platform-express` = Multer)
 * Fastify adapter ostida ishlamaydi — `@UploadedFiles()` bo'sh/undefined
 * keladi yoki interceptor 500 bilan yiqiladi. Shuning uchun upload
 * endpointlar shu helper orqali to'g'ridan-to'g'ri Fastify `req.parts()`
 * dan o'qiydi.
 */
export async function parseMultipart(
  req: FastifyRequest,
): Promise<ParsedMultipart> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const anyReq = req as any;
  if (typeof anyReq.parts !== 'function') {
    throw new BadRequestException('multipart/form-data kutilgan edi');
  }

  const files: Record<string, UploadedPart> = {};
  const fields: Record<string, string> = {};

  try {
    for await (const part of anyReq.parts()) {
      if (part.type === 'file') {
        // Har faylni keyingi part'ga o'tishdan OLDIN to'liq o'qiymiz
        // (Fastify multipart oqimi ketma-ket).
        const buffer: Buffer = await part.toBuffer();
        files[part.fieldname] = {
          buffer,
          mimetype: part.mimetype ?? 'application/octet-stream',
          originalname: part.filename ?? part.fieldname,
        };
      } else {
        fields[part.fieldname] = String(part.value ?? '');
      }
    }
  } catch (err) {
    // Fayl hajmi limitidan oshsa @fastify/multipart shu xatoni beradi.
    if ((err as { code?: string }).code === 'FST_REQ_FILE_TOO_LARGE') {
      throw new PayloadTooLargeException('Fayl hajmi juda katta');
    }
    throw err;
  }

  return { files, fields };
}
