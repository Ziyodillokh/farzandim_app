import { ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, ArrayUnique, IsArray, IsString, MaxLength } from 'class-validator';

/**
 * Bola onboarding'da tanlagan qiziqish tag'larini saqlash uchun.
 * Tag ID'lar `interest_options.dart` (child app) bilan kelishilgan,
 * masalan: `book`, `cartoon`, `sport`, `music`, `animals`, `space`,
 * `tech`, `art`, `food`, `travel`, `science`, `games`.
 */
export class UpdateInterestsDto {
  @ApiProperty({
    description: "Tanlangan qiziqish tag'lari (ID'lar)",
    example: ['book', 'cartoon', 'space'],
    type: [String],
  })
  @IsArray()
  @ArrayMaxSize(20)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(32, { each: true })
  interests!: string[];
}
