import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

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
}
