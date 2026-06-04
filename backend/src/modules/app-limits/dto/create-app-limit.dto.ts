import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateAppLimitDto {
  @ApiProperty({ example: 'com.youtube' })
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  packageName: string;

  // Eski mobil klientlar (appName yuboradigan build'lar) bilan moslik uchun
  // qabul qilinadi, lekin saqlanmaydi (AppLimit modelida appName ustuni yo'q —
  // nom installed-apps'dan olinadi). Bo'lmaganda forbidNonWhitelisted 400 berardi.
  @ApiPropertyOptional({ example: 'YouTube' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  appName?: string;

  @ApiProperty({
    description: 'Daily limit in milliseconds (number or numeric string)',
    example: 900000,
  })
  dailyLimitMs: number | string;

  @ApiPropertyOptional({
    description: 'Weekly limit in milliseconds (number or numeric string)',
    example: 3600000,
  })
  @IsOptional()
  weeklyLimitMs?: number | string;

  @ApiPropertyOptional({ default: true })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean = true;
}
