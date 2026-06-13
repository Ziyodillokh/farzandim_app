import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  MinLength,
  MaxLength,
  IsInt,
  Min,
  Max,
} from 'class-validator';

/**
 * Bola O'ZINI tahrirlaydigan maydonlar (CHILD JWT, `PUT /children/me`).
 * Faqat name/age/region — ota-onaga tegishli sozlamalar (blockAllApps,
 * familyCode, ...) bu yerda yo'q, ularni faqat ota-ona o'zgartiradi.
 */
export class UpdateMyProfileDto {
  @ApiPropertyOptional({ example: 'Ali', minLength: 1, maxLength: 100 })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({ example: 10, minimum: 1, maximum: 25 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(25)
  age?: number;

  @ApiPropertyOptional({ example: 'Toshkent', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  region?: string;
}
