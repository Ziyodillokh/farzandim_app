import { describe, expect, it } from 'vitest';

import { assignmentKind, assignmentTitle, isWrittenAssignment } from '../format';

describe('yozma vazifani aniqlash (backend javobiga bardoshli)', () => {
  it('WRITTEN turi yoki materialId=written — yozma vazifa; katalog materiali — yo\'q', () => {
    expect(isWrittenAssignment({ materialId: 'written', materialKind: 'WRITTEN' })).toBe(true);
    expect(isWrittenAssignment({ materialId: 'written', materialKind: null })).toBe(true);
    expect(isWrittenAssignment({ materialId: 'mat-1', materialKind: 'WRITTEN' })).toBe(true);
    expect(isWrittenAssignment({ materialId: 'mat-1', materialKind: 'VIDEO' })).toBe(false);
  });

  it('nom: yozma vazifada sarlavha, sarlavha bo\'lmasa materialTitle; katalogda materialTitle', () => {
    expect(assignmentTitle({ materialId: 'written', materialKind: 'WRITTEN', title: ' Insho ', materialTitle: '—' })).toBe('Insho');
    expect(assignmentTitle({ materialId: 'written', materialKind: null, title: null, materialTitle: 'Insho (eski)' })).toBe('Insho (eski)');
    expect(assignmentTitle({ materialId: 'mat-1', materialKind: 'VIDEO', title: 'e\'tiborsiz', materialTitle: 'Kasrlar' })).toBe('Kasrlar');
  });

  it('tur: written bo\'lsa WRITTEN, aks holda o\'z turi', () => {
    expect(assignmentKind({ materialId: 'written', materialKind: null })).toBe('WRITTEN');
    expect(assignmentKind({ materialId: 'mat-1', materialKind: 'TEST' })).toBe('TEST');
    expect(assignmentKind({ materialId: 'mat-x', materialKind: null })).toBeNull();
  });
});
