import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class CategoriesQueryDto {
  @ApiPropertyOptional({
    description: 'Filter by content kind: video, audiobook, book',
  })
  @IsString()
  @IsOptional()
  kind?: string;
}
