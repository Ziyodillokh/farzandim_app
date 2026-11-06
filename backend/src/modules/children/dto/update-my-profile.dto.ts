import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  MinLength,
  MaxLength,
  IsInt,
  IsIn,
  Min,
  Max,
  Matches,
} from 'class-validator';
import {
  EDUCATION_LANGUAGES,
  EducationLanguage,
} from '../../child-auth/child-auth.constants';

/** Jins: `create-child.dto` / `update-child.dto` bilan bir xil qiymatlar. */
export const MY_PROFILE_GENDERS = ['male', 'female'] as const;
export type MyProfileGender = (typeof MY_PROFILE_GENDERS)[number];

/**
 * Bola O'ZINI tahrirlaydigan maydonlar (CHILD JWT, `PUT /children/me`).
 * Faqat name/birthDate/age/region — ota-onaga tegishli sozlamalar
 * (blockAllApps, familyCode, ...) bu yerda yo'q, ularni faqat ota-ona
 * o'zgartiradi.
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

  /**
   * Tug'ilgan sana `YYYY-MM-DD`. Berilsa `age` shundan hisoblanadi.
   * Avval bu maydon yo'q edi — shu sabab bola ilovasi yoshdan soxta
   * "01.01.YYYY" yasab ko'rsatardi.
   */
  @ApiPropertyOptional({ example: '2015-03-14' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: "birthDate YYYY-MM-DD formatda bo'lishi kerak",
  })
  birthDate?: string;

  @ApiPropertyOptional({ example: 'Toshkent', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  region?: string;

  /** Jins (A06 profil): 'male' | 'female'. */
  @ApiPropertyOptional({ enum: MY_PROFILE_GENDERS, example: 'female' })
  @IsOptional()
  @IsIn(MY_PROFILE_GENDERS)
  gender?: MyProfileGender;

  /** Ta'lim tili (A06 profil): 'uz' | 'ru' | 'kaa'. */
  @ApiPropertyOptional({ enum: EDUCATION_LANGUAGES, example: 'uz' })
  @IsOptional()
  @IsIn(EDUCATION_LANGUAGES)
  educationLanguage?: EducationLanguage;
}
