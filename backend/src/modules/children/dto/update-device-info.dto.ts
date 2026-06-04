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

  @ApiPropertyOptional({ example: 'MyWiFi' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  wifiName?: string;
}
