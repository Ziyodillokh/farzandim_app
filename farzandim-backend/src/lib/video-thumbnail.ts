// ─────────────────────────────────────────────────────────────────────
// Auto-thumbnail extractor (ffmpeg) — Sprint 5.6f
// ─────────────────────────────────────────────────────────────────────
//
// Admin video yuklaganida thumbnailFile bermasa, biz video'dan
// 1-sekunddagi kadrni JPG sifatida chiqaramiz va MinIO'ga yuklaymiz.
//
// Pipeline:
//   1. Video buffer'ni /tmp/<uuid>.mp4 ga yozish (ffmpeg path kerak)
//   2. `ffmpeg -ss 1 -i input.mp4 -vframes 1 -vf scale=640:-1 output.jpg`
//   3. JPG bayt'larni o'qib qaytarish
//   4. Tmp fayllarni tozalash
//
// Production'da ffmpeg `/usr/bin/ffmpeg` da (Ubuntu 22.04 base image bilan
// keladi). Lokal dev — agar ffmpeg yo'q bo'lsa, helper null qaytaradi va
// upload bashqaruvchi thumbnail'siz davom etadi.

import { spawn } from 'child_process';
import { promises as fs } from 'fs';
import { randomUUID } from 'crypto';
import path from 'path';
import os from 'os';

const FFMPEG_BIN = process.env.FFMPEG_BIN || 'ffmpeg';
const FFMPEG_TIMEOUT_MS = 30_000; // 30 sekund — katta videolar uchun yetadi
const THUMB_SECOND = 1;            // 1-sekundga sakrash (qora kadr'dan qutilish)
const THUMB_WIDTH = 640;           // proporsional balandlik (-1)

export interface ThumbnailExtractResult {
  buffer: Buffer;
  mime: string;
  width: number;
}

/**
 * Video buffer'dan 1-sekunddagi kadrni JPG sifatida ajratib oladi.
 * Muvaffaqiyatsiz bo'lsa null qaytaradi (caller thumbnail'siz davom etadi).
 */
export async function extractVideoThumbnail(
  videoBuf: Buffer,
  videoExt: string,
): Promise<ThumbnailExtractResult | null> {
  const id = randomUUID();
  const tmpVideoPath = path.join(os.tmpdir(), `farzandim-thumb-${id}${videoExt}`);
  const tmpJpgPath = path.join(os.tmpdir(), `farzandim-thumb-${id}.jpg`);

  try {
    // 1. Video bayt'larni tmp faylga yozish
    await fs.writeFile(tmpVideoPath, videoBuf);

    // 2. ffmpeg — 1s'dagi kadrni JPG sifatida olish
    await runFfmpeg([
      '-y',                       // overwrite
      '-ss', String(THUMB_SECOND),
      '-i', tmpVideoPath,
      '-vframes', '1',
      '-vf', `scale=${THUMB_WIDTH}:-1`,
      '-q:v', '3',                // JPG quality (2-31, low=better)
      tmpJpgPath,
    ]);

    // 3. JPG'ni o'qib qaytarish
    const buffer = await fs.readFile(tmpJpgPath);
    if (buffer.length === 0) return null;

    return { buffer, mime: 'image/jpeg', width: THUMB_WIDTH };
  } catch (err) {
    // ffmpeg yo'q, video noto'g'ri, timeout — silent fail, caller'ga null
    console.warn('[video-thumbnail] extract failed:', (err as Error).message);
    return null;
  } finally {
    // 4. Cleanup (errors swallow — file mavjud bo'lmasligi mumkin)
    await fs.unlink(tmpVideoPath).catch(() => {});
    await fs.unlink(tmpJpgPath).catch(() => {});
  }
}

function runFfmpeg(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(FFMPEG_BIN, args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr?.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error(`ffmpeg timeout after ${FFMPEG_TIMEOUT_MS}ms`));
    }, FFMPEG_TIMEOUT_MS);

    child.on('error', (err) => {
      clearTimeout(timer);
      reject(new Error(`ffmpeg spawn failed: ${err.message}`));
    });
    child.on('close', (code) => {
      clearTimeout(timer);
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited ${code}: ${stderr.slice(0, 200)}`));
    });
  });
}
