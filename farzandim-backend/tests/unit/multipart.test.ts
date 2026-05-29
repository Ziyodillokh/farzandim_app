import { describe, expect, test } from 'vitest';
import { getFieldString, getFieldNumber } from '../../src/lib/multipart';

describe('getFieldString', () => {
  test('returns undefined when fields are missing', () => {
    expect(getFieldString(undefined, 'x')).toBeUndefined();
    expect(getFieldString({}, 'x')).toBeUndefined();
  });

  test('returns trimmed value', () => {
    const fields = { name: { value: '  hello  ' } };
    expect(getFieldString(fields, 'name')).toBe('hello');
  });

  test('returns undefined when value is whitespace-only', () => {
    const fields = { name: { value: '   ' } };
    expect(getFieldString(fields, 'name')).toBeUndefined();
  });

  test('returns undefined when field shape is wrong', () => {
    const fields = { name: { notValue: 'x' } as unknown as { value: string } };
    expect(getFieldString(fields, 'name')).toBeUndefined();
  });
});

describe('getFieldNumber', () => {
  test('returns parsed finite number', () => {
    expect(getFieldNumber({ d: { value: '12.5' } }, 'd')).toBe(12.5);
  });

  test('returns undefined for non-numeric strings', () => {
    expect(getFieldNumber({ d: { value: 'abc' } }, 'd')).toBeUndefined();
  });

  test('returns undefined when missing', () => {
    expect(getFieldNumber(undefined, 'd')).toBeUndefined();
  });
});
