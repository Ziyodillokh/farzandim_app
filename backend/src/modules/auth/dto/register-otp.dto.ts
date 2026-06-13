import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches, Length } from 'class-validator';

/**
 * Ro'yxatdan o'tishdan oldin telefon raqamni Eskiz SMS OTP bilan tasdiqlash.
 * `POST /auth/send-register-otp` — kod yuboradi.
 */
export class SendRegisterOtpDto {
  @ApiProperty({ example: '+998901234567' })
  @Matches(/^\+998\d{9}$/, {
    message: "Telefon raqam +998XXXXXXXXX formatda bo'lishi kerak",
  })
  phone!: string;
}

/**
 * `POST /auth/verify-register-otp` — telefon + 5 raqamli kodni tekshiradi.
 */
export class VerifyRegisterOtpDto {
  @ApiProperty({ example: '+998901234567' })
  @Matches(/^\+998\d{9}$/, {
    message: "Telefon raqam +998XXXXXXXXX formatda bo'lishi kerak",
  })
  phone!: string;

  @ApiProperty({ example: '12345', minLength: 5, maxLength: 5 })
  @IsString()
  @Length(5, 5, { message: "Kod 5 ta raqamdan iborat bo'lishi kerak" })
  code!: string;
}
