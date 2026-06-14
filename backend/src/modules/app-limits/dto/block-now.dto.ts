import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';

/** Darhol bloklash (#15) — qaysi ilovani. */
export class BlockNowDto {
  @ApiProperty({ example: 'com.zhiliaoapp.musically' })
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  packageName: string;
}
