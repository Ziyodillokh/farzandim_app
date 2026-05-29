/**
 * Sprint 5.6: seed categories + a handful of demo content rows per type
 * so the Kontent admin pages render meaningful data.
 *
 * Usage on server:
 *   tsx prisma/seed-content.ts
 */
import 'dotenv/config';
import { prisma } from '../src/lib/prisma';

interface CategorySeed {
  kind: 'video' | 'audiobook' | 'book';
  slug: string;
  name: string;
  sortOrder: number;
}

const CATEGORIES: CategorySeed[] = [
  // Videos
  { kind: 'video', slug: 'multfilmlar', name: 'Multfilmlar', sortOrder: 1 },
  { kind: 'video', slug: 'qoshiqlar', name: "Qo'shiqlar", sortOrder: 2 },
  { kind: 'video', slug: 'ta-limiy', name: "Ta'limiy", sortOrder: 3 },
  { kind: 'video', slug: 'sport', name: 'Sport', sortOrder: 4 },
  // Audiobooks
  { kind: 'audiobook', slug: 'badiiy', name: 'Badiiy', sortOrder: 1 },
  { kind: 'audiobook', slug: 'sarguzasht', name: 'Sarguzasht', sortOrder: 2 },
  { kind: 'audiobook', slug: 'ertaklar', name: 'Ertaklar', sortOrder: 3 },
  { kind: 'audiobook', slug: 'fan', name: 'Fan', sortOrder: 4 },
  // Books
  { kind: 'book', slug: 'school', name: 'Maktab darsliklari', sortOrder: 1 },
  { kind: 'book', slug: 'adabiyot', name: 'Adabiyot', sortOrder: 2 },
  { kind: 'book', slug: 'tarjima', name: 'Tarjima', sortOrder: 3 },
];

const VIDEO_TITLES = [
  'Fun Learning ABC Song',
  'Nature Discovery for Kids',
  'Math Adventures Episode 1',
  'Bedtime Story: The Magic Forest',
  'Melody Maker\'s Jingle',
  'Dancing with Dinosaurs',
  'Counting Sheep Lullaby',
  'The Wheels on the Bus',
  'Twinkle Twinkle Little Star',
  'ABC Animal Parade',
];

const AUDIOBOOK_TITLES: { title: string; author: string }[] = [
  { title: "Sherlock Holmes: Qizil o'rganish", author: 'Arthur Conan Doyle' },
  { title: "Kichik shahzoda", author: 'Antoine de Saint-Exupéry' },
  { title: "Alpomish dostonlari", author: "Xalq og'zaki ijodi" },
  { title: "Oshko bo'lgan sir", author: 'Said Ahmad' },
  { title: 'Robinson Kruzo', author: 'Daniel Defoe' },
  { title: 'Hayvonlar olamida', author: 'Rustam Karimov' },
];

const BOOK_ROWS: { title: string; author: string; pages: number; category: string }[] = [
  { title: 'Boshlang\'ich matematika', author: 'Toshkent State', pages: 120, category: 'school' },
  { title: 'O\'zbek tili 4-sinf', author: 'Ona tili', pages: 88, category: 'school' },
  { title: 'Otabek va Kumush', author: 'Abdulla Qodiriy', pages: 240, category: 'adabiyot' },
  { title: 'Harry Potter va falsafa toshi', author: 'J.K. Rowling', pages: 320, category: 'tarjima' },
];

async function main(): Promise<void> {
  // Reset content tables (idempotent re-run)
  await prisma.book.deleteMany();
  await prisma.audiobook.deleteMany();
  await prisma.video.deleteMany();
  await prisma.contentCategory.deleteMany();

  for (const c of CATEGORIES) await prisma.contentCategory.create({ data: c });
  console.log(`Categories: ${CATEGORIES.length}`);

  const videoCats = await prisma.contentCategory.findMany({ where: { kind: 'video' } });
  const audioCats = await prisma.contentCategory.findMany({ where: { kind: 'audiobook' } });

  for (let i = 0; i < VIDEO_TITLES.length; i += 1) {
    const cat = videoCats[i % videoCats.length]!;
    await prisma.video.create({
      data: {
        title: VIDEO_TITLES[i]!,
        url: `https://cdn.farzandimedu.uz/videos/sample-${i + 1}.mp4`,
        thumbnail: `https://cdn.farzandimedu.uz/videos/sample-${i + 1}.jpg`,
        durationSec: 200 + (i % 6) * 60,
        ageFrom: [0, 3, 6, 9, 12][i % 5]!,
        ageTo: [5, 8, 12, 15, 18][i % 5]!,
        categoryId: cat.id,
        category: cat.slug,
        planRequired: ['free', 'basic', 'standard', 'premium'][i % 4]!,
        status: ['approved', 'approved', 'approved', 'pending', 'rejected'][i % 5]!,
        featured: i < 2,
        views: 1000 + i * 1500,
        likes: 50 + i * 80,
      },
    });
  }
  console.log(`Videos: ${VIDEO_TITLES.length}`);

  for (let i = 0; i < AUDIOBOOK_TITLES.length; i += 1) {
    const cat = audioCats[i % audioCats.length]!;
    const a = AUDIOBOOK_TITLES[i]!;
    await prisma.audiobook.create({
      data: {
        title: a.title,
        author: a.author,
        audioUrl: `https://cdn.farzandimedu.uz/audiobooks/${i + 1}.m4a`,
        thumbnail: `https://cdn.farzandimedu.uz/audiobooks/${i + 1}.jpg`,
        durationSec: 45 * 60 + i * 600,
        partsCount: 5 + (i % 8),
        ageFrom: [3, 6, 9, 12][i % 4]!,
        ageTo: [9, 12, 15, 18][i % 4]!,
        categoryId: cat.id,
        category: cat.slug,
        planRequired: ['free', 'basic', 'premium'][i % 3]!,
        status: ['approved', 'approved', 'approved', 'pending', 'rejected', 'approved'][i % 6]!,
        listens: 200 + i * 400,
      },
    });
  }
  console.log(`Audiobooks: ${AUDIOBOOK_TITLES.length}`);

  for (let i = 0; i < BOOK_ROWS.length; i += 1) {
    const b = BOOK_ROWS[i]!;
    await prisma.book.create({
      data: {
        title: b.title,
        author: b.author,
        pages: b.pages,
        category: b.category,
        pdfUrl: `https://cdn.farzandimedu.uz/books/${i + 1}.pdf`,
        coverUrl: `https://cdn.farzandimedu.uz/books/${i + 1}.jpg`,
        ageFrom: 8 + i,
        ageTo: 15 + i,
        planRequired: i === 0 ? 'free' : 'standard',
        status: 'approved',
        reads: 150 + i * 120,
      },
    });
  }
  console.log(`Books: ${BOOK_ROWS.length}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
