import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsString } from 'class-validator';
import { APP_CATEGORIES } from '../../installed-apps/app-category.util';

/** Kategoriya bloklash/ochish (#14). */
export class ToggleCategoryDto {
  @ApiProperty({ enum: APP_CATEGORIES, example: 'SOCIAL' })
  @IsString()
  @IsIn(APP_CATEGORIES)
  category: string;

  @ApiProperty({ description: 'true = blokla, false = blokdan chiqar' })
  @IsBoolean()
  block: boolean;
}
