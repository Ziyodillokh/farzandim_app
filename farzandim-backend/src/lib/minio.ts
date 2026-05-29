import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  CreateBucketCommand,
  HeadBucketCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from '../config/env';

// Internal client — upload/delete uchun (lokal MinIO, tezroq)
export const s3 = new S3Client({
  endpoint: env.MINIO_ENDPOINT,
  region: 'us-east-1',
  credentials: {
    accessKeyId: env.MINIO_ACCESS_KEY,
    secretAccessKey: env.MINIO_SECRET_KEY,
  },
  forcePathStyle: true,
});

// Public client — signed URL generatsiya uchun (mobile/brauzer ulanadi).
// MINIO_PUBLIC_URL endpointidan signed URL yaratiladi → Nginx orqali backend MinIO'ga proxy bo'ladi.
// Agar MINIO_PUBLIC_URL = MINIO_ENDPOINT (dev environment), s3'ni qayta ishlatamiz.
const s3Public =
  env.MINIO_PUBLIC_URL && env.MINIO_PUBLIC_URL !== env.MINIO_ENDPOINT
    ? new S3Client({
        endpoint: env.MINIO_PUBLIC_URL,
        region: 'us-east-1',
        credentials: {
          accessKeyId: env.MINIO_ACCESS_KEY,
          secretAccessKey: env.MINIO_SECRET_KEY,
        },
        forcePathStyle: true,
      })
    : s3;

export const BUCKETS = {
  voice: 'farzandim-voice',
  video: 'farzandim-video',
  avatars: 'farzandim-avatars',
  appIcons: 'farzandim-app-icons',
  // Sprint 5.6b — admin content uploads
  contentVideos: 'farzandim-content-videos',
  contentAudio: 'farzandim-content-audio',
  contentBooks: 'farzandim-content-books', // Sprint 5.6d — PDF kitoblar
  contentThumbnails: 'farzandim-content-thumbs',
} as const;

export type BucketName = (typeof BUCKETS)[keyof typeof BUCKETS];

/**
 * Server startup'da bucket'lar mavjudligini tekshiradi, yo'q bo'lsa yaratadi.
 * Idempotent — mavjud bo'lsa hech narsa qilmaydi.
 */
export async function ensureBuckets(): Promise<void> {
  for (const bucket of Object.values(BUCKETS)) {
    try {
      await s3.send(new HeadBucketCommand({ Bucket: bucket }));
    } catch {
      try {
        await s3.send(new CreateBucketCommand({ Bucket: bucket }));
        console.log(`[minio] Created bucket: ${bucket}`);
      } catch (err) {
        console.error(`[minio] Failed to create bucket ${bucket}:`, err);
      }
    }
  }
}

export async function uploadFile(
  bucket: BucketName,
  key: string,
  body: Buffer,
  contentType: string
): Promise<void> {
  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: body,
      ContentType: contentType,
    })
  );
}

export async function deleteFile(bucket: BucketName, key: string): Promise<void> {
  await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
}

// AWS SigV4 (va MinIO o'sha standardni qo'llaydi) signed URL'larida maks
// expiry 7 kun (604800 s). Foydalanuvchi tomonidan o'tib qo'yilgan
// qiymatni shu chegaraga clamp qilamiz — aks holda S3 client xato qaytaradi.
export const MAX_SIGNED_URL_TTL_SECONDS = 7 * 24 * 60 * 60 - 60; // 6 kun 23:59 (xavfsizlik margin)

export async function getDownloadUrl(
  bucket: BucketName,
  key: string,
  expiresIn = 3600
): Promise<string> {
  const command = new GetObjectCommand({ Bucket: bucket, Key: key });
  const safeExpires = Math.min(expiresIn, MAX_SIGNED_URL_TTL_SECONDS);
  // Public client (MINIO_PUBLIC_URL) — mobile/brauzer'da host ko'rinadi
  return getSignedUrl(s3Public, command, { expiresIn: safeExpires });
}
