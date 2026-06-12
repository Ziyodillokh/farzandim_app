import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsOptional, IsIn, IsUUID, IsISO8601, IsInt, Min, Max } from 'class-validator';

export class ListVideoMessagesDto {
  @ApiPropertyOptional({ enum: ['sent', 'received'], description: 'Filter by role' })
  @IsOptional()
  @IsIn(['sent', 'received'])
  role?: 'sent' | 'received';

  // Faqat shu user bilan yozishmalar (chat ekrani). peerId berilsa role e'tiborga olinmaydi.
  @ApiPropertyOptional({ description: 'Only messages exchanged with this user id' })
  @IsOptional()
  @IsUUID()
  peerId?: string;

  // Cursor: shu vaqtdan eski xabarlar qaytadi (chat'da yuqoriga scroll).
  @ApiPropertyOptional({ description: 'Return messages created before this ISO date' })
  @IsOptional()
  @IsISO8601()
  before?: string;

  @ApiPropertyOptional({ description: 'Page size (default 100, max 100)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
