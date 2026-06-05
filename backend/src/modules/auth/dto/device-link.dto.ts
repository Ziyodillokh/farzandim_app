import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/**
 * QR orqali ikkinchi qurilmani ulash (device-link) — redeem so'rovi.
 * `code` mas'ul qurilmada yaratilgan QR ichidagi qisqa muddatli token.
 *
 * DIQQAT: har maydonda class-validator dekoratori SHART (global
 * ValidationPipe whitelist + forbidNonWhitelisted), aks holda "property X
 * should not exist" 400 qaytaradi.
 */
export class RedeemDeviceLinkDto {
  @ApiProperty({ example: 'a1b2c3d4e5f6' })
  @IsString()
  @MinLength(4)
  @MaxLength(128)
  code!: string;

  @ApiPropertyOptional({ example: 'Redmi Note 12' })
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
