import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * Ota-ona (PARENT) ro'yxatdan o'tishi — email YOKI telefon + parol.
 * Kamida bittasi (email yoki phone) berilishi shart (service tekshiradi).
 */
export class RegisterDto {
  @ApiPropertyOptional({ example: 'ota@example.com' })
  @IsOptional()
  @IsEmail({}, { message: "Email noto'g'ri formatda" })
  email?: string;

  @ApiPropertyOptional({ example: '+998901234567' })
  @IsOptional()
  @Matches(/^\+998\d{9}$/, {
    message: "Telefon raqam +998XXXXXXXXX formatda bo'lishi kerak",
  })
  phone?: string;

  @ApiProperty({ example: 'Parol123', minLength: 6 })
  @IsString()
  @MinLength(6, { message: "Parol kamida 6 ta belgidan iborat bo'lishi kerak" })
  @MaxLength(72, { message: "Parol 72 ta belgidan oshmasligi kerak" })
  password!: string;

  @ApiPropertyOptional({ example: 'Ahmad Aliyev' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({
    example: 'Redmi Note 12S',
    description: 'Qurilma modeli (Faol sessiyalar)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceModel?: string;

  @ApiPropertyOptional({ example: 'android', enum: ['android', 'ios', 'web'] })
  @IsOptional()
  @IsString()
  @MaxLength(16)
  platform?: string;
}
