import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNumber,
  IsString,
  IsOptional,
  IsUrl,
  MaxLength,
} from 'class-validator';

export class TelegramAuthDto {
  @ApiProperty({ example: 123456789, description: 'Telegram user ID' })
  @IsNumber()
  id!: number;

  @ApiPropertyOptional({ example: 'John' })
  @IsOptional()
  @IsString()
  first_name?: string;

  @ApiPropertyOptional({ example: 'Doe' })
  @IsOptional()
  @IsString()
  last_name?: string;

  @ApiPropertyOptional({ example: 'johndoe' })
  @IsOptional()
  @IsString()
  username?: string;

  @ApiPropertyOptional({ example: 'https://t.me/i/userpic/320/photo.jpg' })
  @IsOptional()
  @IsUrl()
  photo_url?: string;

  @ApiProperty({ example: 1700000000, description: 'Unix timestamp of auth' })
  @IsNumber()
  auth_date!: number;

  @ApiProperty({ description: 'HMAC-SHA256 hash from Telegram' })
  @IsString()
  hash!: string;

  @ApiPropertyOptional({
    example: 'Redmi Note 12S',
    description: 'Qurilma modeli (Faol sessiyalar)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceModel?: string;

  @ApiPropertyOptional({ example: 'web', enum: ['android', 'ios', 'web'] })
  @IsOptional()
  @IsString()
  @MaxLength(16)
  platform?: string;
}
