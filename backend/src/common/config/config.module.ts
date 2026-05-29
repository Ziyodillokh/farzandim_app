import { ConfigModule } from '@nestjs/config';
import { validate } from './env.schema';

export const AppConfigModule = ConfigModule.forRoot({
  isGlobal: true,
  validate,
});
