import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsISO8601, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Bola qurilmasi o'yin (CATEGORY_GAME) foreground'ga chiqqanini xabar qiladi.
 * Backend ota-onaga push yuboradi ("{ism} {o'yin} o'ynayapti" + Bloklash).
 */
export class GameOpenDto {
  @ApiProperty({ example: 'com.supercell.clashofclans' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  packageName!: string;

  @ApiProperty({ example: 'Clash of Clans' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  appName!: string;

  /** O'yin ochilgan vaqt (qurilma). Oflayn navbatdan kech kelgan eski xabar push qilinmaydi. */
  @ApiPropertyOptional({ example: '2026-11-14T08:00:00.000Z' })
  @IsOptional()
  @IsISO8601()
  openedAt?: string;
}
