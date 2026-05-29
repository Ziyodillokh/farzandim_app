import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsUUID, Min } from 'class-validator';

export class SingleAnswerDto {
  @ApiProperty()
  @IsUUID()
  questionId: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  selectedIndex: number;
}
