// ─────────────────────────────────────────────────────────────────────
// Admin content upload helpers — Sprint 5.6b
// ─────────────────────────────────────────────────────────────────────
//
// Multipart upload pattern for admin Videos / Audiobooks / Books:
//
//   POST /admin/{videos,audiobooks,books}/upload
//   FormData:
//     file:           main asset (video / audio / pdf)
//     thumbnailFile?: optional cover image
//     metadata:       JSON string with title, description, ageFrom, ageTo, ...
//
// Bucket'lar `lib/minio.ts` BUCKETS'da:
//   - contentVideos      farzandim-content-videos
//   - contentAudio       farzandim-content-audio
//   - contentBooks       farzandim-content-books
//   - contentThumbnails  farzandim-content-thumbs

import { randomUUID } from 'crypto';
import type { MultipartFile } from '@fastify/multipart';
import { BUCKETS, type BucketName, uploadFile, getDownloadUrl } from './minio';

export interface UploadedAsset {
  storagePath: string;
  publicUrl: string;
  contentType: string;
  bytes: number;
}

/**
 * Streamdan buffer olib MinIO'ga yuklash. Faqat oddiy small/medium fayllar
 * uchun (buffer in-memory). Katta video uchun streaming variant qo'shilishi
 * mumkin (kelajak optimizatsiya).
 */
export async function uploadAssetToBucket(
  file: MultipartFile,
  bucket: BucketName,
  /** Storage key prefix — masalan 'videos' yoki 'audio'. */
  prefix: string,
  /** Bayt cheklov (xavfsizlik) — true qaytarsa fayl tashlanadi. */
  maxBytes: number,
): Promise<UploadedAsset> {
  const buffer = await file.toBuffer();
  if (buffer.length > maxBytes) {
    throw new Error(`File too large: ${buffer.length} > ${maxBytes}`);
  }
  const id = randomUUID();
  const ext = extensionFor(file.filename);
  const storagePath = `${prefix}/${id}${ext}`;
  await uploadFile(bucket, storagePath, buffer, file.mimetype);
  const publicUrl = await getDownloadUrl(bucket, storagePath, 60 * 60 * 24 * 6); // 6 kun (AWS SigV4 maks 7)
  return {
    storagePath,
    publicUrl,
    contentType: file.mimetype,
    bytes: buffer.length,
  };
}

function extensionFor(filename: string): string {
  const i = filename.lastIndexOf('.');
  if (i < 0) return '';
  const ext = filename.slice(i).toLowerCase();
  // Faqat oddiy a-z0-9 belgilarni saqlaymiz (xavfsizlik)
  return /^[.a-z0-9]+$/.test(ext) && ext.length <= 6 ? ext : '';
}

export const ALLOWED_VIDEO_MIMES = [
  'video/mp4',
  'video/quicktime',
  'video/webm',
  'video/3gpp',
  'video/x-matroska',
];

export const ALLOWED_AUDIO_MIMES = [
  'audio/mp4',
  'audio/m4a',
  'audio/aac',
  'audio/mpeg',
  'audio/ogg',
  'audio/wav',
  'audio/webm',
];

// Sprint 5.6d — PDF kitoblar uchun
export const ALLOWED_PDF_MIMES = [
  'application/pdf',
];

export const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];

export { BUCKETS };
