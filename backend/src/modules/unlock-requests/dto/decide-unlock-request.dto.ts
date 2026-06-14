import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator';

/** Ota-ona qarori: rad etish yoki 5–60 daqiqa qo'shimcha vaqt. */
export class DecideUnlockRequestDto {
  @ApiProperty({ description: 'true = ruxsat, false = rad etish', example: true })
  @IsBoolean()
  approve: boolean;

  @ApiPropertyOptional({
    description: 'approve=true bo\'lsa berilgan daqiqalar (5..60)',
    example: 30,
    minimum: 5,
    maximum: 60,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(5)
  @Max(60)
  minutes?: number;
}
