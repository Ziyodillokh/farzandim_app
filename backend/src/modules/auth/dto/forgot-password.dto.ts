import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsOptional,
  IsString,
  Length,
  Matches,
  MinLength,
} from 'class-validator';

/**
 * `POST /auth/password/forgot` — logout holatida parol tiklash uchun OTP so'rash.
 * Telefon YOKI email beriladi (kamida bittasi). Enumeration himoyasi uchun
 * javob har doim generic ("agar akkaunt mavjud bo'lsa, kod yuborildi").
 */
export class ForgotPasswordRequestDto {
  @ApiPropertyOptional({ example: '+998901234567' })
  @IsOptional()
  @Matches(/^\+998\d{9}$/, {
    message: "Telefon raqam +998XXXXXXXXX formatda bo'lishi kerak",
  })
  phone?: string;

  @ApiPropertyOptional({ example: 'user@example.com' })
  @IsOptional()
  @IsEmail({}, { message: "Email noto'g'ri" })
  email?: string;
}

/**
 * `POST /auth/password/reset` — OTP kodni tekshirib yangi parol o'rnatadi.
 */
export class ForgotPasswordResetDto {
  @ApiPropertyOptional({ example: '+998901234567' })
  @IsOptional()
  @Matches(/^\+998\d{9}$/, {
    message: "Telefon raqam +998XXXXXXXXX formatda bo'lishi kerak",
  })
  phone?: string;

  @ApiPropertyOptional({ example: 'user@example.com' })
  @IsOptional()
  @IsEmail({}, { message: "Email noto'g'ri" })
  email?: string;

  @ApiProperty({ example: '12345', minLength: 5, maxLength: 5 })
  @IsString()
  @Length(5, 5, { message: "Kod 5 ta raqamdan iborat bo'lishi kerak" })
  code!: string;

  @ApiProperty({ example: 'yangiParol123', minLength: 6 })
  @IsString()
  @MinLength(6, { message: "Parol kamida 6 ta belgidan iborat bo'lishi kerak" })
  newPassword!: string;
}
