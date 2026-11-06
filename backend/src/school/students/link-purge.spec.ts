import { deleteGuardianReviewsOfUsers, deleteLinkDataOfChildren } from './link-purge';

describe('deleteLinkDataOfChildren', () => {
  function makeTx(invites: string[], corrections: string[]) {
    return {
      schoolStudentInvite: {
        findMany: jest.fn().mockResolvedValue(invites.map((id) => ({ id }))),
        deleteMany: jest.fn().mockResolvedValue({ count: invites.length }),
      },
      schoolLinkCorrection: {
        findMany: jest.fn().mockResolvedValue(corrections.map((id) => ({ id }))),
        deleteMany: jest.fn().mockResolvedValue({ count: corrections.length }),
      },
      schoolStaffNotification: { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) },
    };
  }

  it('does nothing for an empty child list', async () => {
    const tx = makeTx([], []);

    await deleteLinkDataOfChildren(tx as never, []);

    expect(tx.schoolStudentInvite.findMany).not.toHaveBeenCalled();
    expect(tx.schoolStudentInvite.deleteMany).not.toHaveBeenCalled();
  });

  it('does not touch notifications when the children have no link data', async () => {
    const tx = makeTx([], []);

    await deleteLinkDataOfChildren(tx as never, ['c1']);

    expect(tx.schoolStaffNotification.deleteMany).not.toHaveBeenCalled();
    expect(tx.schoolStudentInvite.deleteMany).not.toHaveBeenCalled();
    expect(tx.schoolLinkCorrection.deleteMany).not.toHaveBeenCalled();
  });

  it('deletes the notifications first (ids come from the rows), then the invites and corrections of those children only', async () => {
    const tx = makeTx(['i1', 'i2'], ['k1']);
    const order: string[] = [];
    tx.schoolStaffNotification.deleteMany.mockImplementation(async () => void order.push('notifications'));
    tx.schoolStudentInvite.deleteMany.mockImplementation(async () => void order.push('invites'));
    tx.schoolLinkCorrection.deleteMany.mockImplementation(async () => void order.push('corrections'));

    await deleteLinkDataOfChildren(tx as never, ['c1', 'c2']);

    expect(tx.schoolStaffNotification.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['link-review:i1', 'link-review:i2', 'link-correction:k1'] } },
    });
    expect(tx.schoolStudentInvite.deleteMany).toHaveBeenCalledWith({ where: { studentChildId: { in: ['c1', 'c2'] } } });
    expect(tx.schoolLinkCorrection.deleteMany).toHaveBeenCalledWith({ where: { childId: { in: ['c1', 'c2'] } } });
    expect(order).toEqual(['notifications', 'invites', 'corrections']);
  });
});

describe('deleteGuardianReviewsOfUsers', () => {
  function makeTx(reviews: string[]) {
    return {
      schoolGuardianReview: {
        findMany: jest.fn().mockResolvedValue(reviews.map((id) => ({ id }))),
        deleteMany: jest.fn().mockResolvedValue({ count: reviews.length }),
      },
      schoolStaffNotification: { deleteMany: jest.fn().mockResolvedValue({ count: reviews.length }) },
    };
  }

  it('does nothing for an empty user list or users without reviews', async () => {
    const tx = makeTx([]);

    await deleteGuardianReviewsOfUsers(tx as never, []);
    await deleteGuardianReviewsOfUsers(tx as never, ['u1']);

    expect(tx.schoolGuardianReview.findMany).toHaveBeenCalledTimes(1);
    expect(tx.schoolGuardianReview.deleteMany).not.toHaveBeenCalled();
    expect(tx.schoolStaffNotification.deleteMany).not.toHaveBeenCalled();
  });

  it('deletes the notifications first (ids come from the rows), then the reviews of those users only', async () => {
    const tx = makeTx(['r1', 'r2']);
    const order: string[] = [];
    tx.schoolStaffNotification.deleteMany.mockImplementation(async () => void order.push('notifications'));
    tx.schoolGuardianReview.deleteMany.mockImplementation(async () => void order.push('reviews'));

    await deleteGuardianReviewsOfUsers(tx as never, ['u1', 'u2']);

    expect(tx.schoolGuardianReview.findMany).toHaveBeenCalledWith({ where: { userId: { in: ['u1', 'u2'] } }, select: { id: true } });
    expect(tx.schoolStaffNotification.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['guardian-review:r1', 'guardian-review:r2'] } },
    });
    expect(tx.schoolGuardianReview.deleteMany).toHaveBeenCalledWith({ where: { userId: { in: ['u1', 'u2'] } } });
    expect(order).toEqual(['notifications', 'reviews']);
  });
});
