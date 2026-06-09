import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/**
 * Bola QR kodni skanerlab kelganda yuborilgan body.
 * `token` — Parent'ning `POST /auth/child/:id/repair-qr` chaqirig'idan kelgan
 * 32-belgili hex string (45s amal qiladi).
 */
export class RedeemRepairTokenDto {
  @ApiProperty({ description: 'QR kod tokeni (32-char hex)' })
  @IsString()
  @MinLength(16)
  @MaxLength(64)
  token!: string;

  @ApiPropertyOptional({
    description: "Yangi bola qurilmasi modeli (Redmi 12, iPhone 14 ...)",
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceModel?: string;

  @ApiPropertyOptional({ enum: ['android', 'ios', 'web'] })
  @IsOptional()
  @IsString()
  @MaxLength(16)
  platform?: string;
}
