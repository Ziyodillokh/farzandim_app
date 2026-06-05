import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
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

  // DIQQAT: class-validator dekoratori SHART. `whitelist: true` dekoratorsiz
  // maydonni o'chiradi va `forbidNonWhitelisted` "property dailyLimitMs should
  // not exist" 400 qaytaradi (avval shu sabab limit umuman saqlanmasdi).
  // `@Type(() => Number)` raqamli string'ni ham qabul qiladi (transform: true).
  // 0 = bloklash.
  @ApiProperty({
    description: 'Daily limit in milliseconds (0 = block)',
    example: 900000,
  })
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  dailyLimitMs: number;

  @ApiPropertyOptional({
    description: 'Weekly limit in milliseconds',
    example: 3600000,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  weeklyLimitMs?: number;

  @ApiPropertyOptional({ default: true })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean = true;
}
