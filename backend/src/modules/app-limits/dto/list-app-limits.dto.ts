import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class ListAppLimitsDto {
  @ApiPropertyOptional({ example: 'true' })
  @IsString()
  @IsOptional()
  isActive?: string;
}
