// Kirish (K1) xatolari — javob `{ statusCode, code, message }` (+ qo'shimcha maydonlar).
// Ommaviy (autentifikatsiyasiz) yo'llar login / bola / maktab mavjudligini hech qachon ochmaydi.

import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import type { PasswordIssue } from './child-credentials.helpers';

/** Noto'g'ri login YOKI noto'g'ri parol — ikkalasi uchun bir xil javob. */
export const invalidCredentials = () =>
  new UnauthorizedException({ code: 'INVALID_CREDENTIALS', message: 'Invalid credentials' });

/**
 * To'g'ri, lekin muddati (14 kun) o'tgan vaqtinchalik parol: setupToken berilmaydi. Parolni bilmaydigan odamga hech
 * narsa ochmaydi (noto'g'ri parol baribir INVALID_CREDENTIALS). Tiklash so'rovi bilan yangisi olinadi.
 */
export const tempPasswordExpired = () =>
  new UnauthorizedException({ code: 'TEMP_PASSWORD_EXPIRED', message: 'Temporary password has expired' });

/** Bitta IP'dan juda ko'p XATO urinish (muvaffaqiyatli kirish sanalmaydi). */
export const ipRateLimited = (retryAfterSeconds: number) =>
  new HttpException(
    { code: 'RATE_LIMITED', message: 'Too many requests', retryAfterSeconds },
    HttpStatus.TOO_MANY_REQUESTS,
  );

/** Blok: login (yoki xotiradagi "soya" hisob) 15 daqiqaga bloklangan. */
export const lockedError = (retryAfterSeconds: number) =>
  new HttpException(
    { code: 'LOCKED', message: 'Too many failed attempts', retryAfterSeconds },
    HttpStatus.TOO_MANY_REQUESTS,
  );

export const setupTokenInvalid = () =>
  new UnauthorizedException({ code: 'SETUP_TOKEN_INVALID', message: 'Setup token is invalid or expired' });

export const weakPassword = (reason: PasswordIssue) =>
  new BadRequestException({ code: 'WEAK_PASSWORD', reason, message: 'Password does not meet the requirements' });

export const wrongPassword = () =>
  new BadRequestException({ code: 'WRONG_PASSWORD', message: 'Current password is incorrect' });

export const noCredential = () =>
  new NotFoundException({ code: 'NO_CREDENTIAL', message: 'No login credentials for this account' });

export const loginTaken = () => new ConflictException({ code: 'LOGIN_TAKEN', message: 'Login is already taken' });

export const childNotFound = () => new NotFoundException({ code: 'CHILD_NOT_FOUND', message: 'Child not found' });

export const requestNotFound = () =>
  new NotFoundException({ code: 'REQUEST_NOT_FOUND', message: 'Recovery request not found' });

export const requestAlreadyResolved = () =>
  new ConflictException({ code: 'ALREADY_RESOLVED', message: 'Recovery request is already resolved' });
