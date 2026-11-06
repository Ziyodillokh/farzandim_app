import { ConflictException } from '@nestjs/common';
import { linkChildToStudent, tryLinkChildToStudent } from './link-core';

interface TxOptions {
  holderParentId?: string | null;
  current?: { id: string; archived: boolean; school: { status: string } } | null;
}

/** Faqat `tryLinkChildToStudent` ishlatadigan delegatlar; yozuvlar `writes` ga to'planadi. */
function makeTx({ holderParentId, current = null }: TxOptions = {}) {
  const writes: string[] = [];
  const tx = {
    child: { findUnique: jest.fn().mockResolvedValue(holderParentId === undefined ? null : holderParentId === null ? null : { parentId: holderParentId }) },
    schoolStudent: {
      findFirst: jest.fn().mockResolvedValue(current),
      update: jest.fn().mockImplementation(async (args: { where: { id: string }; data: { childId: string | null } }) => {
        writes.push(`student:${args.where.id}=${args.data.childId}`);
      }),
    },
    schoolStudentInvite: {
      findMany: jest.fn().mockResolvedValue([{ id: 'inv-old' }]),
      updateMany: jest.fn().mockImplementation(async () => void writes.push('invites:free')),
    },
    schoolLinkCorrection: {
      findMany: jest.fn().mockResolvedValue([{ id: 'cor-old' }]),
      updateMany: jest.fn().mockImplementation(async () => void writes.push('corrections:cancel')),
    },
    schoolStaffNotification: { deleteMany: jest.fn().mockResolvedValue({ count: 1 }) },
  };
  return { tx, writes };
}

const CHILD = { id: 'child-x', parentId: 'parent-1' };

describe('tryLinkChildToStudent', () => {
  it('links a free student to a free child', async () => {
    const { tx, writes } = makeTx();

    await expect(tryLinkChildToStudent(tx as never, { id: 's1', childId: null }, CHILD)).resolves.toBe('LINKED');

    expect(writes).toEqual(['student:s1=child-x']);
  });

  it('is a no-op when the student already belongs to this child', async () => {
    const { tx, writes } = makeTx();

    await expect(tryLinkChildToStudent(tx as never, { id: 's1', childId: 'child-x' }, CHILD)).resolves.toBe('SAME');

    expect(writes).toEqual([]);
    expect(tx.schoolStudent.findFirst).not.toHaveBeenCalled();
  });

  it('refuses a student linked to another family without writing anything', async () => {
    const { tx, writes } = makeTx({ holderParentId: 'parent-2' });

    await expect(tryLinkChildToStudent(tx as never, { id: 's1', childId: 'rival' }, CHILD)).resolves.toBe('STUDENT_LINKED_ELSEWHERE');

    expect(writes).toEqual([]);
  });

  it('replaces a sibling of the same family and cleans the sibling\'s code slots and open corrections', async () => {
    const { tx, writes } = makeTx({ holderParentId: 'parent-1' });

    await expect(tryLinkChildToStudent(tx as never, { id: 's1', childId: 'sibling' }, CHILD)).resolves.toBe('LINKED');

    expect(writes).toEqual(['invites:free', 'corrections:cancel', 'student:s1=child-x']);
  });

  it('refuses a child that is linked to another ACTIVE student', async () => {
    const { tx, writes } = makeTx({ current: { id: 's2', archived: false, school: { status: 'ACTIVE' } } });

    await expect(tryLinkChildToStudent(tx as never, { id: 's1', childId: null }, CHILD)).resolves.toBe('ALREADY_ENROLLED');

    expect(writes).toEqual([]);
  });

  it.each([
    ['archived student', { id: 's2', archived: true, school: { status: 'ACTIVE' } }],
    ['suspended school', { id: 's2', archived: false, school: { status: 'SUSPENDED' } }],
  ])('moves the child away from a stale link (%s) before linking, like the parent PUT', async (_name, current) => {
    const { tx, writes } = makeTx({ current });

    await expect(tryLinkChildToStudent(tx as never, { id: 's1', childId: null }, CHILD)).resolves.toBe('LINKED');

    expect(writes).toEqual(['student:s2=null', 'student:s1=child-x']);
  });
});

describe('linkChildToStudent', () => {
  it('turns obstacles into 409 errors with stable codes and returns whether anything changed', async () => {
    const elsewhere = makeTx({ holderParentId: 'parent-2' });
    const enrolled = makeTx({ current: { id: 's2', archived: false, school: { status: 'ACTIVE' } } });

    const first = await linkChildToStudent(elsewhere.tx as never, { id: 's1', childId: 'rival' }, CHILD).catch((e) => e);
    const second = await linkChildToStudent(enrolled.tx as never, { id: 's1', childId: null }, CHILD).catch((e) => e);

    expect(first).toBeInstanceOf(ConflictException);
    expect((first as ConflictException).getResponse()).toMatchObject({ code: 'STUDENT_LINKED_ELSEWHERE' });
    expect((second as ConflictException).getResponse()).toMatchObject({ code: 'ALREADY_ENROLLED' });
    await expect(linkChildToStudent(makeTx().tx as never, { id: 's1', childId: null }, CHILD)).resolves.toBe(true);
    await expect(linkChildToStudent(makeTx().tx as never, { id: 's1', childId: 'child-x' }, CHILD)).resolves.toBe(false);
  });
});
