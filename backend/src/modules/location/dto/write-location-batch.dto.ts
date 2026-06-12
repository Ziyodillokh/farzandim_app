import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, ValidateNested } from 'class-validator';
import { WriteLocationDto } from './write-location.dto';

// Offline buferdan yig'ilgan nuqtalarni bitta so'rovda yuborish uchun —
// har nuqtaga alohida HTTP o'rniga. Har nuqta o'z capturedAt'i bilan keladi.
export class WriteLocationBatchDto {
  @ApiProperty({ type: [WriteLocationDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => WriteLocationDto)
  points!: WriteLocationDto[];
}
