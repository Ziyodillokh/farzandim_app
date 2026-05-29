import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateAppLimitDto {
  @ApiPropertyOptional({
    description: 'Daily limit in milliseconds',
    example: 900000,
  })
  @IsOptional()
  dailyLimitMs?: number | string;

  @ApiPropertyOptional({
    description: 'Weekly limit in milliseconds (null to remove)',
    example: 3600000,
  })
  @IsOptional()
  weeklyLimitMs?: number | string | null;

  @ApiPropertyOptional()
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
