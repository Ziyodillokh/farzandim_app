// ─────────────────────────────────────────────────────────────────────
// MinIO orphan content fayllarini tozalash
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 5.6'gacha delete endpoint'lar faqat DB row'ni o'chirardi —
// MinIO fayllar orphan bo'lib qolardi. Bu skript:
//   1. Har content bucket'i ichidagi haqiqiy fayllar ro'yxati
//   2. DB'da references (storage_key, thumb_storage_key)
//   3. Difference (MinIO − DB) — orphans → DELETE
//
// Usage: tsx scripts/cleanup-content-orphans.ts [--dry-run]
//        --dry-run — faqat hisoblaydi, hech narsa o'chirmaydi

import { S3Client, ListObjectsV2Command } from '@aws-sdk/client-s3';
import { prisma } from '../src/lib/prisma';
import { BUCKETS, deleteFile, type BucketName } from '../src/lib/minio';
import { env } from '../src/config/env';

const s3 = new S3Client({
  endpoint: env.MINIO_ENDPOINT,
  region: 'us-east-1',
  credentials: {
    accessKeyId: env.MINIO_ACCESS_KEY,
    secretAccessKey: env.MINIO_SECRET_KEY,
  },
  forcePathStyle: true,
});

const isDryRun = process.argv.includes('--dry-run');

async function listAllKeys(bucket: BucketName): Promise<string[]> {
  const keys: string[] = [];
  let continuationToken: string | undefined;
  do {
    const cmd = new ListObjectsV2Command({
      Bucket: bucket,
      ContinuationToken: continuationToken,
    });
    const resp = await s3.send(cmd);
    for (const obj of resp.Contents ?? []) {
      if (obj.Key) keys.push(obj.Key);
    }
    continuationToken = resp.IsTruncated ? resp.NextContinuationToken : undefined;
  } while (continuationToken);
  return keys;
}

async function cleanupBucket(
  bucket: BucketName,
  referencedKeys: Set<string>,
): Promise<{ total: number; orphans: number; deleted: number }> {
  const all = await listAllKeys(bucket);
  const orphans = all.filter((k) => !referencedKeys.has(k));
  let deleted = 0;
  if (!isDryRun) {
    for (const key of orphans) {
      try {
        await deleteFile(bucket, key);
        deleted += 1;
        console.log(`  [DEL] ${bucket}/${key}`);
      } catch (err) {
        console.warn(`  [SKIP] ${bucket}/${key}: ${(err as Error).message}`);
      }
    }
  } else {
    for (const key of orphans) {
      console.log(`  [DRY] ${bucket}/${key}`);
    }
  }
  return { total: all.length, orphans: orphans.length, deleted };
}

async function main(): Promise<void> {
  console.log(`MinIO orphan cleanup ${isDryRun ? '(DRY RUN)' : ''}`);
  console.log();

  // 1. DB'da references
  const videos = await prisma.video.findMany({
    select: { storageKey: true, thumbStorageKey: true },
  });
  const audiobooks = await prisma.audiobook.findMany({
    select: { storageKey: true, thumbStorageKey: true },
  });
  const books = await prisma.book.findMany({
    select: { storageKey: true, thumbStorageKey: true },
  });

  const videoKeys = new Set(videos.map((v) => v.storageKey).filter((k): k is string => !!k));
  const audioKeys = new Set(audiobooks.map((a) => a.storageKey).filter((k): k is string => !!k));
  const bookKeys = new Set(books.map((b) => b.storageKey).filter((k): k is string => !!k));
  const thumbKeys = new Set([
    ...videos.map((v) => v.thumbStorageKey),
    ...audiobooks.map((a) => a.thumbStorageKey),
    ...books.map((b) => b.thumbStorageKey),
  ].filter((k): k is string => !!k));

  console.log(`DB references: videos=${videoKeys.size}, audio=${audioKeys.size}, books=${bookKeys.size}, thumbs=${thumbKeys.size}`);
  console.log();

  // 2. Har bucket uchun cleanup
  const buckets: Array<[BucketName, Set<string>]> = [
    [BUCKETS.contentVideos, videoKeys],
    [BUCKETS.contentAudio, audioKeys],
    [BUCKETS.contentBooks, bookKeys],
    [BUCKETS.contentThumbnails, thumbKeys],
  ];
  let totalOrphans = 0;
  let totalDeleted = 0;
  for (const [bucket, refs] of buckets) {
    console.log(`▶ ${bucket}`);
    const result = await cleanupBucket(bucket, refs);
    console.log(`  total: ${result.total}, orphans: ${result.orphans}, deleted: ${result.deleted}`);
    totalOrphans += result.orphans;
    totalDeleted += result.deleted;
    console.log();
  }

  console.log(`Summary: ${totalOrphans} orphans, ${totalDeleted} deleted${isDryRun ? ' (dry run)' : ''}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
