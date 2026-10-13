import { readExifOrientation, stripImageMetadata } from './image-metadata';

const SECRET = 'GPS-41.3111-69.2797';

function segment(marker: number, payload: Buffer): Buffer {
  const header = Buffer.alloc(4);
  header[0] = 0xff;
  header[1] = marker;
  header.writeUInt16BE(payload.length + 2, 2);
  return Buffer.concat([header, payload]);
}

/** Little-endian TIFF: Orientation + (soxta) GPS matni bilan Exif payload. */
function exifPayload(orientation: number): Buffer {
  const tiff = Buffer.alloc(8 + 2 + 2 * 12 + 4);
  tiff.write('II', 0, 'ascii');
  tiff.writeUInt16LE(0x2a, 2);
  tiff.writeUInt32LE(8, 4);
  tiff.writeUInt16LE(2, 8);
  // 0x8825 GPS IFD pointer (qiymati muhim emas — testda matn qidiramiz)
  tiff.writeUInt16LE(0x8825, 10);
  tiff.writeUInt16LE(4, 12);
  tiff.writeUInt32LE(1, 14);
  tiff.writeUInt32LE(0, 18);
  tiff.writeUInt16LE(0x0112, 22);
  tiff.writeUInt16LE(3, 24);
  tiff.writeUInt32LE(1, 26);
  tiff.writeUInt16LE(orientation, 30);
  return Buffer.concat([Buffer.from('Exif\0\0', 'binary'), tiff, Buffer.from(SECRET)]);
}

function jpeg(orientation: number): Buffer {
  return Buffer.concat([
    Buffer.from([0xff, 0xd8]),
    segment(0xe0, Buffer.from('JFIF\0\x01\x01\0\0\x01\0\x01\0\0', 'binary')),
    segment(0xe1, exifPayload(orientation)),
    segment(0xfe, Buffer.from(`comment ${SECRET}`)),
    segment(0xdb, Buffer.alloc(65, 1)),
    Buffer.from([0xff, 0xda, 0x00, 0x08, 1, 2, 3, 4, 5, 6, 0x11, 0x22, 0xff, 0xd9]),
  ]);
}

function pngChunk(type: string, data: Buffer): Buffer {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  return Buffer.concat([len, Buffer.from(type, 'ascii'), data, Buffer.alloc(4)]);
}

function webpChunk(type: string, data: Buffer): Buffer {
  const size = Buffer.alloc(4);
  size.writeUInt32LE(data.length, 0);
  const pad = data.length % 2 ? Buffer.alloc(1) : Buffer.alloc(0);
  return Buffer.concat([Buffer.from(type, 'ascii'), size, data, pad]);
}

describe('stripImageMetadata', () => {
  it('removes EXIF/GPS and comments from a JPEG but keeps orientation', () => {
    // Arrange
    const input = jpeg(6);

    // Act
    const out = stripImageMetadata(input);

    // Assert
    expect(out.includes(Buffer.from(SECRET))).toBe(false);
    expect(out.subarray(0, 2)).toEqual(Buffer.from([0xff, 0xd8]));
    expect(out[3]).toBe(0xe0); // APP0 (JFIF) birinchi bo'lib qoladi
    const app1At = out.indexOf(Buffer.from([0xff, 0xe1]));
    expect(app1At).toBeGreaterThan(0);
    expect(readExifOrientation(out.subarray(app1At + 4))).toBe(6);
    expect(out.subarray(out.length - 2)).toEqual(Buffer.from([0xff, 0xd9]));
  });

  it('drops the EXIF block entirely when orientation is normal', () => {
    const out = stripImageMetadata(jpeg(1));

    expect(out.indexOf(Buffer.from([0xff, 0xe1]))).toBe(-1);
    expect(out.includes(Buffer.from(SECRET))).toBe(false);
  });

  it('does not mutate the input buffer', () => {
    const input = jpeg(6);
    const copy = Buffer.from(input);

    stripImageMetadata(input);

    expect(input.equals(copy)).toBe(true);
  });

  it('removes eXIf and text chunks from a PNG', () => {
    const input = Buffer.concat([
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      pngChunk('IHDR', Buffer.alloc(13)),
      pngChunk('eXIf', Buffer.from(SECRET)),
      pngChunk('tEXt', Buffer.from(`Location\0${SECRET}`)),
      pngChunk('IDAT', Buffer.alloc(10, 7)),
      pngChunk('IEND', Buffer.alloc(0)),
    ]);

    const out = stripImageMetadata(input);

    expect(out.includes(Buffer.from(SECRET))).toBe(false);
    expect(out.includes(Buffer.from('IDAT'))).toBe(true);
    expect(out.includes(Buffer.from('IEND'))).toBe(true);
  });

  it('removes EXIF/XMP chunks from a WebP and fixes header + flags', () => {
    const vp8x = Buffer.alloc(10);
    vp8x[0] = 0x08 | 0x04 | 0x10; // EXIF + XMP + alpha
    const body = Buffer.concat([
      webpChunk('VP8X', vp8x),
      webpChunk('VP8L', Buffer.alloc(9, 3)),
      webpChunk('EXIF', Buffer.from(SECRET)),
      webpChunk('XMP ', Buffer.from(SECRET)),
    ]);
    const header = Buffer.alloc(12);
    header.write('RIFF', 0, 'ascii');
    header.writeUInt32LE(body.length + 4, 4);
    header.write('WEBP', 8, 'ascii');

    const out = stripImageMetadata(Buffer.concat([header, body]));

    expect(out.includes(Buffer.from(SECRET))).toBe(false);
    expect(out.readUInt32LE(4)).toBe(out.length - 8);
    expect(out[20]).toBe(0x10); // faqat alpha bayrog'i qoldi
  });

  it('returns unknown or truncated data unchanged', () => {
    const garbage = Buffer.from('not an image');
    const truncated = jpeg(6).subarray(0, 30);

    expect(stripImageMetadata(garbage)).toBe(garbage);
    expect(stripImageMetadata(truncated)).toBe(truncated);
  });
});
