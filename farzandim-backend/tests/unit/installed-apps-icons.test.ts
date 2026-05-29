import { describe, expect, test } from 'vitest';

// Sof funksiyalar — installed-apps icon decode + sanitize.
// Backend module ichidan import emas (Prisma init kerak), shu yerda kopiya.

function decodeIconBase64(raw: string): { buffer: Buffer; mime: string } | null {
  try {
    let data = raw;
    let mime = 'image/png';
    if (raw.startsWith('data:')) {
      const m = /^data:([^;]+);base64,(.+)$/.exec(raw);
      if (!m) return null;
      mime = m[1];
      data = m[2];
    }
    const buffer = Buffer.from(data, 'base64');
    return { buffer, mime };
  } catch {
    return null;
  }
}

function sanitizePackageKey(packageName: string): string {
  return packageName.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 200);
}

describe('decodeIconBase64', () => {
  test('decodes raw base64 PNG', () => {
    // 1x1 transparent PNG
    const raw = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    const result = decodeIconBase64(raw);
    expect(result).not.toBeNull();
    expect(result!.mime).toBe('image/png');
    expect(result!.buffer.length).toBeGreaterThan(0);
    // PNG signature: 0x89 0x50 0x4E 0x47
    expect(result!.buffer[0]).toBe(0x89);
    expect(result!.buffer[1]).toBe(0x50);
    expect(result!.buffer[2]).toBe(0x4e);
    expect(result!.buffer[3]).toBe(0x47);
  });

  test('strips data URL prefix', () => {
    const raw = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    const result = decodeIconBase64(raw);
    expect(result).not.toBeNull();
    expect(result!.mime).toBe('image/png');
  });

  test('detects different MIME from data URL', () => {
    const raw = 'data:image/jpeg;base64,/9j/4AAQ';
    const result = decodeIconBase64(raw);
    expect(result).not.toBeNull();
    expect(result!.mime).toBe('image/jpeg');
  });

  test('returns null for malformed data URL', () => {
    expect(decodeIconBase64('data:not-a-real-url')).toBeNull();
  });

  test('accepts empty base64 (will fail size check elsewhere)', () => {
    const result = decodeIconBase64('');
    expect(result).not.toBeNull();
    expect(result!.buffer.length).toBe(0);
  });
});

describe('sanitizePackageKey', () => {
  test('preserves valid Android package names', () => {
    expect(sanitizePackageKey('com.google.android.youtube')).toBe('com.google.android.youtube');
    expect(sanitizePackageKey('com.instagram.android')).toBe('com.instagram.android');
  });

  test('replaces slashes with underscore', () => {
    expect(sanitizePackageKey('com.foo/bar')).toBe('com.foo_bar');
  });

  test('replaces other unsafe chars', () => {
    expect(sanitizePackageKey('com.app:foo bar')).toBe('com.app_foo_bar');
  });

  test('truncates to 200 chars', () => {
    const long = 'a'.repeat(300);
    const result = sanitizePackageKey(long);
    expect(result.length).toBe(200);
  });

  test('preserves underscores and hyphens', () => {
    expect(sanitizePackageKey('com.app_name-v2')).toBe('com.app_name-v2');
  });
});
