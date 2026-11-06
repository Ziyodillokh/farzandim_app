// Bola ↔ maktab bog'lanishi xatolari: `{ statusCode, code, message }`. Xabarlarda maktab / o'quvchi nomi YO'Q.

import { ConflictException, HttpException, HttpStatus, NotFoundException } from '@nestjs/common';

/** Noto'g'ri, muddati o'tgan, yopilgan yoki o'rni band kod (sababi ataylab ajratilmaydi). */
export class CodeInvalidException extends NotFoundException {
  constructor() {
    super({ code: 'CODE_INVALID', message: 'Code is invalid or expired' });
  }
}

export const alreadyEnrolled = () =>
  new ConflictException({ code: 'ALREADY_ENROLLED', message: 'Child is already linked to a student' });

export const studentLinkedElsewhere = () =>
  new ConflictException({ code: 'STUDENT_LINKED_ELSEWHERE', message: 'Linked by another family member' });

/** Arxivdagi o'quvchiga kod yaratib bo'lmaydi (K1 ham shu kodni ishlatadi — panel aynan moslaydi). */
export const studentArchived = () =>
  new ConflictException({ code: 'STUDENT_ARCHIVED', message: 'Student is archived' });

export const childNotFound = () => new NotFoundException({ code: 'CHILD_NOT_FOUND', message: 'Child not found' });

export const linkRequestNotFound = () =>
  new NotFoundException({ code: 'NOT_FOUND', message: 'Link request not found' });

export const requestStale = () =>
  new ConflictException({ code: 'REQUEST_STALE', message: 'Link request is no longer open' });

export const locked = (retryAfterSeconds: number) =>
  new HttpException(
    { code: 'LOCKED', message: 'Too many invalid codes', retryAfterSeconds },
    HttpStatus.TOO_MANY_REQUESTS,
  );

export const tooManyCorrections = () =>
  new HttpException(
    { code: 'TOO_MANY_REQUESTS', message: 'Daily correction limit reached' },
    HttpStatus.TOO_MANY_REQUESTS,
  );
