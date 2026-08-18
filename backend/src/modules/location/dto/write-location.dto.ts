import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsOptional,
  IsUUID,
  IsBoolean,
  IsInt,
  Min,
  Max,
  MaxLength,
} from 'class-validator';

export class WriteLocationDto {
  @ApiProperty({ description: 'Child ID (UUID)', example: 'uuid-here' })
  @IsUUID()
  childId!: string;

  @ApiProperty({ example: 41.2995, minimum: -90, maximum: 90 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @ApiProperty({ example: 69.2401, minimum: -180, maximum: 180 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  @ApiPropertyOptional({ example: 12.5, description: 'GPS accuracy in meters' })
  @IsOptional()
  @IsNumber()
  accuracy?: number;

  @ApiPropertyOptional({ example: 2.3, description: 'Speed in m/s' })
  @IsOptional()
  @IsNumber()
  speed?: number;

  // Bola ilovasi GPS'dan heading/altitude ham yuboradi. Hozir saqlanmaydi,
  // lekin DTO'da e'lon qilinishi SHART — aks holda global ValidationPipe
  // (whitelist + forbidNonWhitelisted) butun so'rovni "property heading
  // should not exist" deb 400 bilan rad etadi va lokatsiya saqlanmaydi.
  @ApiPropertyOptional({ example: 90.0, description: 'Heading in degrees (0-360)' })
  @IsOptional()
  @IsNumber()
  heading?: number;

  @ApiPropertyOptional({ example: 450.0, description: 'Altitude in meters' })
  @IsOptional()
  @IsNumber()
  altitude?: number;

  @ApiPropertyOptional({ example: 85, minimum: 0, maximum: 100 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  isCharging?: boolean;

  @ApiPropertyOptional({ example: 'Samsung Galaxy A52', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  deviceModel?: string;

  @ApiPropertyOptional({ example: 'Android 13', maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  androidVersion?: string;

  @ApiPropertyOptional({ example: '1.2.0', maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  appVersion?: string;

  /**
   * ESKIRGAN — qabul qilinadi, lekin SAQLANMAYDI (2026-08-18).
   * Google Play Families "Device Identifiers": bola qurilmasidan SSID
   * yig'ish taqiqlangan. Yangi klientlar (child >= SSID-fix) uni yubormaydi;
   * maydon faqat ESKI APK'lar (versionCode<=5) validatsiyada 400 olmasligi
   * uchun qoldirildi. location.service.ts qiymatni e'tiborsiz qoldiradi.
   */
  @ApiPropertyOptional({ deprecated: true, maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  wifiName?: string;

  @ApiPropertyOptional({
    description:
      'Client timestamp (ISO 8601) — offline buffer flush paytida to\'g\'ri ' +
      'stop-detection uchun. Bo\'lmasa server vaqti ishlatiladi.',
    example: '2026-06-05T09:41:00.000Z',
  })
  @IsOptional()
  @IsString()
  capturedAt?: string;
}
