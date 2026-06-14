import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/** Bola yuboradigan "qo'shimcha vaqt" so'rovi. */
export class CreateUnlockRequestDto {
  @ApiProperty({ enum: ['APP', 'SCREEN_TIME'], example: 'APP' })
  @IsString()
  @IsIn(['APP', 'SCREEN_TIME'])
  kind: 'APP' | 'SCREEN_TIME';

  @ApiPropertyOptional({
    description: 'APP uchun ilova paketi; SCREEN_TIME uchun yuborilmaydi',
    example: 'com.google.android.youtube',
  })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  packageName?: string;

  @ApiPropertyOptional({
    description: "Bola so'ragan qo'shimcha daqiqalar (5..60)",
    example: 15,
    minimum: 5,
    maximum: 60,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(5)
  @Max(60)
  requestedMinutes?: number;

  @ApiPropertyOptional({
    description: 'Bola yozgan sabab (ixtiyoriy)',
    example: 'Darsga tayyorlanishim kerak',
  })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}
