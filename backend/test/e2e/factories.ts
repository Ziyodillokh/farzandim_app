// E2E fabrikalar: ota-ona, bola (ulangan) va ularning access tokenlari.

import { JwtService } from '@nestjs/jwt';
import type { PrismaClient } from '@prisma/client';
import { randomInt, randomUUID } from 'node:crypto';

const consumerJwt = () =>
  new JwtService({
    secret: process.env.JWT_ACCESS_SECRET,
    signOptions: {
      audience: 'farzandim-consumer',
      issuer: 'farzandim-backend',
      expiresIn: '1h',
    },
  });

export interface TestParent {
  userId: string;
  token: string;
}

export interface TestChild {
  childId: string;
  userId: string;
  parentId: string;
  token: string;
}

export function consumerToken(userId: string, role: 'PARENT' | 'CHILD'): string {
  return consumerJwt().sign({ userId, role, tokenVersion: 0 });
}

export async function createParent(
  prisma: PrismaClient,
  overrides: { language?: string; name?: string } = {},
): Promise<TestParent> {
  const user = await prisma.user.create({
    data: {
      role: 'PARENT',
      email: `parent-${randomUUID()}@e2e.test`,
      name: overrides.name ?? 'Ota-ona',
      language: overrides.language ?? 'uz',
    },
  });
  return { userId: user.id, token: consumerToken(user.id, 'PARENT') };
}

export async function createChild(
  prisma: PrismaClient,
  parent: TestParent,
  overrides: { name?: string; age?: number } = {},
): Promise<TestChild> {
  const user = await prisma.user.create({ data: { role: 'CHILD' } });
  const child = await prisma.child.create({
    data: {
      parentId: parent.userId,
      childUserId: user.id,
      name: overrides.name ?? 'Aziz',
      age: overrides.age ?? 12,
      familyCode: String(randomInt(10000, 99999)) + randomUUID().slice(0, 4),
      pairedAt: new Date(),
    },
  });
  return {
    childId: child.id,
    userId: user.id,
    parentId: parent.userId,
    token: consumerToken(user.id, 'CHILD'),
  };
}
