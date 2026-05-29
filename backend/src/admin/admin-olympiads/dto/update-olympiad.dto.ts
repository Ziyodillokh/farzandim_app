import { PartialType, OmitType } from '@nestjs/swagger';
import { CreateOlympiadDto } from './create-olympiad.dto';

export class UpdateOlympiadDto extends PartialType(
  OmitType(CreateOlympiadDto, ['questions'] as const),
) {}
