# Farzandim Backend

O'zbekiston parental control app — backend (Node.js + TypeScript + Fastify + Prisma).

## Stack

- Runtime: Node.js v22
- Framework: Fastify
- Database: PostgreSQL 14 + Prisma
- Storage: MinIO (S3-compatible)
- Auth: Telegram Login + JWT
- Server: Ubuntu 22.04 (Toshkent)

## Setup

\`\`\`bash
npm install
cp .env.example .env
# Edit .env with real values
npx prisma migrate dev
npm run build
npm start
\`\`\`

## Compliance

ZRU-547 — barcha foydalanuvchi ma'lumotlari O'zbekiston serverida saqlanadi.

## License

Proprietary © 2026 Farzandim.
