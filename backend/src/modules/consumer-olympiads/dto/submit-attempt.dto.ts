import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class AnswerDto {
  @ApiProperty()
  @IsUUID()
  questionId: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  selectedIndex: number;
}

export class SubmitAttemptDto {
  @ApiProperty({ type: [AnswerDto] })
  @IsArray()
  @ArrayMinSize(0)
  @ValidateNested({ each: true })
  @Type(() => AnswerDto)
  answers: AnswerDto[];

  @ApiPropertyOptional({ default: 0 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  timeSec?: number = 0;
}
