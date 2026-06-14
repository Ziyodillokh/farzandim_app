import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

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
}
