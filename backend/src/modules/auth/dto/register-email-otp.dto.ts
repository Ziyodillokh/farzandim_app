import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, Length } from 'class-validator';

/**
 * Ro'yxatdan o'tishdan oldin email manzilni OTP kod bilan tasdiqlash
 * (telefon SMS OTP bilan bir xil oqim — nodemailer orqali).
 * `POST /auth/send-register-email-otp` — kod yuboradi.
 */
export class SendRegisterEmailOtpDto {
  @ApiProperty({ example: 'ota@example.com' })
  @IsEmail({}, { message: "Email noto'g'ri formatda" })
  email!: string;
}

/**
 * `POST /auth/verify-register-email-otp` — email + 5 raqamli kodni tekshiradi.
 */
export class VerifyRegisterEmailOtpDto {
  @ApiProperty({ example: 'ota@example.com' })
  @IsEmail({}, { message: "Email noto'g'ri formatda" })
  email!: string;

  @ApiProperty({ example: '12345', minLength: 5, maxLength: 5 })
  @IsString()
  @Length(5, 5, { message: "Kod 5 ta raqamdan iborat bo'lishi kerak" })
  code!: string;
}
