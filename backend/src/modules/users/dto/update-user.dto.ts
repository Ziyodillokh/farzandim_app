import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  MinLength,
  MaxLength,
  IsEnum,
  IsUrl,
} from 'class-validator';

export enum Language {
  UZ = 'uz',
  RU = 'ru',
  EN = 'en',
}

export class UpdateUserDto {
  @ApiPropertyOptional({ example: 'Anvar', minLength: 1, maxLength: 100 })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({
    example: 'https://example.com/avatar.jpg',
    nullable: true,
  })
  @IsOptional()
  @IsUrl()
  avatarUrl?: string | null;

  @ApiPropertyOptional({ enum: Language, example: 'uz' })
  @IsOptional()
  @IsEnum(Language)
  language?: Language;
}
