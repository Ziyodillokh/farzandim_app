import { deleteChildAuthOfChildren } from './child-auth-purge';

describe('deleteChildAuthOfChildren', () => {
  function fakeTx(requests: Array<{ id: string }>) {
    return {
      childRecoveryRequest: {
        findMany: jest.fn().mockResolvedValue(requests),
        deleteMany: jest.fn().mockResolvedValue({ count: requests.length }),
      },
      schoolStaffNotification: { deleteMany: jest.fn().mockResolvedValue({ count: requests.length }) },
      childCredential: { deleteMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
  }

  it('removes the staff notifications, the recovery requests and the credentials of the children', async () => {
    const tx = fakeTx([{ id: 'r1' }, { id: 'r2' }]);

    await deleteChildAuthOfChildren(tx as never, ['c1', 'c2']);

    expect(tx.schoolStaffNotification.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['child-recovery:r1', 'child-recovery:r2'] } },
    });
    expect(tx.childRecoveryRequest.deleteMany).toHaveBeenCalledWith({ where: { childId: { in: ['c1', 'c2'] } } });
    expect(tx.childCredential.deleteMany).toHaveBeenCalledWith({ where: { childId: { in: ['c1', 'c2'] } } });
  });

  it('still removes credentials when there are no recovery requests', async () => {
    const tx = fakeTx([]);

    await deleteChildAuthOfChildren(tx as never, ['c1']);

    expect(tx.schoolStaffNotification.deleteMany).not.toHaveBeenCalled();
    expect(tx.childRecoveryRequest.deleteMany).not.toHaveBeenCalled();
    expect(tx.childCredential.deleteMany).toHaveBeenCalledTimes(1);
  });

  it('does nothing for an empty list', async () => {
    const tx = fakeTx([]);

    await deleteChildAuthOfChildren(tx as never, []);

    expect(tx.childRecoveryRequest.findMany).not.toHaveBeenCalled();
    expect(tx.childCredential.deleteMany).not.toHaveBeenCalled();
  });
});
