import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  MinLength,
  MaxLength,
  IsInt,
  Min,
  Max,
  IsEnum,
  IsBoolean,
  IsArray,
  IsIn,
} from 'class-validator';

export enum Gender {
  MALE = 'male',
  FEMALE = 'female',
}

export class UpdateChildDto {
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

  @ApiPropertyOptional({ enum: Gender, example: 'male' })
  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @ApiPropertyOptional({ example: 'Toshkent', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  region?: string;

  @ApiPropertyOptional({ example: '+998901234567', maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phoneNumber?: string;

  @ApiPropertyOptional({
    example: true,
    description:
      "Notanish manbalardan ilovalar — Play'dan boshqa manbadan o'rnatilgan " +
      'ilovalarni bloklash (true = bloklansin).',
  })
  @IsOptional()
  @IsBoolean()
  blockUnknownSources?: boolean;

  @ApiPropertyOptional({
    example: true,
    description:
      'Barcha ilovalarni bloklash — ota-ona dashboard toggle\'i ' +
      '(true = bola qurilmasidagi barcha ilovalar bloklanadi).',
  })
  @IsOptional()
  @IsBoolean()
  blockAllApps?: boolean;

  @ApiPropertyOptional({
    example: true,
    description:
      "Xavfsiz internet filtri — ota-ona ixtiyoriy yoqadigan tashqi web " +
      'filtri (true = yoqilsin). Faqat Android\'da enforce qilinadi.',
  })
  @IsOptional()
  @IsBoolean()
  webFilterEnabled?: boolean;

  @ApiPropertyOptional({
    example: ['ADULT', 'GAMBLING'],
    description:
      'Bloklangan web kategoriyalari: ADULT | GAMBLING | SOCIAL. Bo\'sh ' +
      'array = hech biri (webFilterEnabled true bo\'lsa ham).',
    isArray: true,
    enum: ['ADULT', 'GAMBLING', 'SOCIAL'],
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @IsIn(['ADULT', 'GAMBLING', 'SOCIAL'], { each: true })
  blockedWebCategories?: string[];
}
