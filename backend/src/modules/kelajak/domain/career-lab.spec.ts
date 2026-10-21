import { buildKelajakBankRows } from '../../../../scripts/kelajak/build-bank-migration';
import { CAREER_LAB_LABELS, careerLabLabel } from './career-lab';
import { careerLabRiasec } from './scoring';

const labRows = buildKelajakBankRows().filter((q) => q.category === 'career_lab');
const codeOf = (externalId: string) => careerLabRiasec(labRows.find((q) => q.externalId === externalId)!);

describe('kelajak career lab', () => {
  it('bankdagi har Career Lab savolining nomi bor va aksincha', () => {
    expect(labRows).toHaveLength(20);
    expect(Object.keys(CAREER_LAB_LABELS).sort()).toEqual(labRows.map((q) => q.externalId).sort());
  });

  it('RIASEC kodi ma\'lumotda (scoring.riasec); umumiy savollar (Q193, Q208, Q210–Q212) — kodsiz', () => {
    const general = labRows.filter((q) => careerLabRiasec(q) === null).map((q) => q.externalId);
    expect(general).toEqual(['PARVOZ-Q193', 'PARVOZ-Q208', 'PARVOZ-Q210', 'PARVOZ-Q211', 'PARVOZ-Q212']);
    expect(labRows.find((q) => q.externalId === 'PARVOZ-Q194')?.scoring).toMatchObject({
      method: 'reflection_rating',
      dimension: 'career_lab_enjoyment',
      riasec: 'R',
    });
  });

  it('namunaviy xarita va noma\'lum savol', () => {
    expect(codeOf('PARVOZ-Q194')).toBe('R');
    expect(codeOf('PARVOZ-Q203')).toBe('I');
    expect(codeOf('PARVOZ-Q204')).toBe('A');
    expect(codeOf('PARVOZ-Q205')).toBe('E');
    expect(codeOf('PARVOZ-Q202')).toBe('C');
    expect(codeOf('PARVOZ-Q207')).toBe('S');
    expect(careerLabLabel('PARVOZ-Q194')?.uz).toBe('Biror narsa yasash');
    expect(careerLabLabel('ADMIN-12345678')).toBeNull();
    expect(careerLabLabel('constructor')).toBeNull();
  });

  it('kod faqat Career Lab kategoriyasida o\'qiladi', () => {
    expect(careerLabRiasec({ category: 'career_lab', scoring: { riasec: 'E' } })).toBe('E');
    expect(careerLabRiasec({ category: 'learning', scoring: { riasec: 'E' } })).toBeNull();
    expect(careerLabRiasec({ category: 'career_lab', scoring: { riasec: 'X' } })).toBeNull();
    expect(careerLabRiasec({ category: 'career_lab', scoring: null })).toBeNull();
  });
});
