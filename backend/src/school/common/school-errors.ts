// Maktab API xatolari — panel `ServiceError` kodlari bilan bir xil:
// javob `{ statusCode, code, message }`. VALIDATION xabari `"maydon: errors.form.x"`
// shaklida (panel forma xatosini shu bo'yicha tarjima qiladi).

import { HttpException, HttpStatus } from '@nestjs/common';

export type SchoolErrorCode = 'FORBIDDEN' | 'NOT_FOUND' | 'VALIDATION' | 'CONFLICT';

const STATUS: Record<SchoolErrorCode, HttpStatus> = {
  FORBIDDEN: HttpStatus.FORBIDDEN,
  NOT_FOUND: HttpStatus.NOT_FOUND,
  VALIDATION: HttpStatus.BAD_REQUEST,
  CONFLICT: HttpStatus.CONFLICT,
};

export class SchoolError extends HttpException {
  constructor(
    readonly code: SchoolErrorCode,
    message: string,
  ) {
    super({ code, message }, STATUS[code]);
  }
}

export const forbidden = (message: string) => new SchoolError('FORBIDDEN', message);
export const notFound = (message: string) => new SchoolError('NOT_FOUND', message);
export const invalid = (message: string) => new SchoolError('VALIDATION', message);
export const conflict = (message: string) => new SchoolError('CONFLICT', message);
