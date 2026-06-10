import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  MinLength,
  MaxLength,
  IsInt,
  Min,
  Max,
  IsEnum,
} from 'class-validator';

export enum Gender {
  MALE = 'male',
  FEMALE = 'female',
}

export class CreateChildDto {
  @ApiProperty({ example: 'Ali', minLength: 1, maxLength: 100 })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name!: string;

  @ApiPropertyOptional({ example: 10, minimum: 1, maximum: 25 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(25)
  age?: number;

  @ApiPropertyOptional({ enum: Gender, example: 'male' })
  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @ApiPropertyOptional({ example: 'Toshkent', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  region?: string;

  @ApiPropertyOptional({ example: '+998901234567', maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phoneNumber?: string;
}
