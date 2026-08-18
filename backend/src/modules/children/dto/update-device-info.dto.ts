import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Bola qurilmasi heartbeat — GPS talab qilmaydi. Child App ilova ochiq
 * yoki fon xizmatda davriy yuboradi. Backend Child yozuvini + lastSeenAt
 * ni yangilaydi, shu orqali ota-ona "Qurilma sozlamalari"da real model,
 * batareya, online holatni ko'radi.
 */
export class UpdateDeviceInfoDto {
  @ApiPropertyOptional({ example: 85, minimum: 0, maximum: 100 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isCharging?: boolean;

  @ApiPropertyOptional({ example: 'samsung SM-N950F' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceModel?: string;

  @ApiPropertyOptional({ example: 'Android 14' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  androidVersion?: string;

  @ApiPropertyOptional({ example: '2.0.0' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  appVersion?: string;

  /** ESKIRGAN — qabul qilinadi, lekin SAQLANMAYDI (2026-08-18, Families
   *  Device Identifiers). Faqat eski APK'lar 400 olmasligi uchun. */
  @ApiPropertyOptional({ deprecated: true })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  wifiName?: string;

  // ─── OS-ruxsat holatlari (Block 4) — bola qurilmasining ruxsatlari ───
  @ApiPropertyOptional({ example: true, description: 'Lokatsiya ruxsati berilganmi' })
  @IsOptional()
  @IsBoolean()
  locationPermission?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Bildirishnoma ruxsati berilganmi' })
  @IsOptional()
  @IsBoolean()
  notificationPermission?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Fon faolligi (batareya istisno) ruxsati' })
  @IsOptional()
  @IsBoolean()
  backgroundAllowed?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Accessibility xizmati yoqilganmi' })
  @IsOptional()
  @IsBoolean()
  accessibilityEnabled?: boolean;

  @ApiPropertyOptional({
    example: true,
    description: "PACKAGE_USAGE_STATS (Foydalanish ma'lumotlari) ruxsati berilganmi",
  })
  @IsOptional()
  @IsBoolean()
  usagePermission?: boolean;
}
