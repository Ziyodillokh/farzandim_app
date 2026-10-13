import {
  IOS_SELECTION_PACKAGE,
  classifyPackage,
  isCategorizable,
} from './app-category.util';

describe('app-category.util — iOS virtual element', () => {
  it("virtual iPhone elementi kategoriya bloklariga kirmaydi", () => {
    expect(isCategorizable(IOS_SELECTION_PACKAGE)).toBe(false);
  });

  it('oddiy paketlar kategoriyalanadi', () => {
    expect(isCategorizable('org.telegram.messenger')).toBe(true);
    expect(classifyPackage('org.telegram.messenger')).toBe('SOCIAL');
  });
});
