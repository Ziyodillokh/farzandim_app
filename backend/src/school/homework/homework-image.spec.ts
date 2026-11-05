import { homeworkPhotoKey, sniffImage } from './homework-image';

const pad = (head: Buffer, total = 32) => Buffer.concat([head, Buffer.alloc(Math.max(0, total - head.length))]);

describe('sniffImage (magic bytes)', () => {
  it('recognises JPEG, PNG and WebP', () => {
    expect(sniffImage(pad(Buffer.from([0xff, 0xd8, 0xff, 0xe0])))).toEqual({ contentType: 'image/jpeg', ext: 'jpg' });
    expect(sniffImage(pad(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])))).toEqual({ contentType: 'image/png', ext: 'png' });
    expect(sniffImage(pad(Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WEBP')])))).toEqual({ contentType: 'image/webp', ext: 'webp' });
  });

  it('rejects HEIC/HEIF: its EXIF/GPS cannot be stripped', () => {
    expect(sniffImage(pad(Buffer.concat([Buffer.alloc(4), Buffer.from('ftypheic')])))).toBeNull();
    expect(sniffImage(pad(Buffer.concat([Buffer.alloc(4), Buffer.from('ftypmif1')])))).toBeNull();
  });

  it('rejects other content that merely claims to be an image', () => {
    expect(sniffImage(Buffer.from('<html><script>alert(1)</script></html>'))).toBeNull();
    expect(sniffImage(Buffer.from('%PDF-1.7 fake'))).toBeNull();
    expect(sniffImage(pad(Buffer.concat([Buffer.alloc(4), Buffer.from('ftypmp42')])))).toBeNull();
    expect(sniffImage(Buffer.from('GIF89a......'))).toBeNull();
  });

  it('rejects empty and truncated buffers', () => {
    expect(sniffImage(Buffer.alloc(0))).toBeNull();
    expect(sniffImage(Buffer.from([0xff, 0xd8]))).toBeNull();
    expect(sniffImage(Buffer.from('RIFF'))).toBeNull();
  });
});

describe('homeworkPhotoKey', () => {
  it('namespaces objects by school, assignment and student', () => {
    expect(homeworkPhotoKey({ schoolId: 's', assignmentId: 'a', studentId: 'st', uuid: 'u', ext: 'jpg' })).toBe('homework/s/a/st/u.jpg');
  });
});
