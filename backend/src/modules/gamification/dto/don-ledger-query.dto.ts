import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export const LEDGER_DEFAULT_LIMIT = 50;
export const LEDGER_MAX_LIMIT = 100;

/** `GET /children/:childId/don-ledger` so'rov parametrlari. */
export class DonLedgerQueryDto {
  @ApiPropertyOptional({ description: 'Oldingi javobdagi nextCursor (opaque)' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  cursor?: string;

  @ApiPropertyOptional({ default: LEDGER_DEFAULT_LIMIT, minimum: 1, maximum: LEDGER_MAX_LIMIT })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(LEDGER_MAX_LIMIT)
  limit?: number;
}
