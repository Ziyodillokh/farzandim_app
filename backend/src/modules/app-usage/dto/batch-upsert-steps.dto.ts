import { ApiProperty } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsString,
  Matches,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class StepEntryDto {
  @ApiProperty({ example: '2026-06-07' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: "date YYYY-MM-DD formatda bo'lsin" })
  date: string;

  @ApiProperty({ example: 5230 })
  @IsInt()
  @Min(0)
  steps: number;
}

export class BatchUpsertStepsDto {
  @ApiProperty({ type: [StepEntryDto] })
  @IsArray()
  @ArrayMaxSize(31)
  @ValidateNested({ each: true })
  @Type(() => StepEntryDto)
  entries: StepEntryDto[];
}
