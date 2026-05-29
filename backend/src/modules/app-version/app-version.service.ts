import {
  Injectable,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { readFileSync } from 'fs';
import { join } from 'path';

type PlatformInfo = {
  latest: string;
  minSupported: string;
  playStoreUrl?: string;
  appStoreUrl?: string;
  directApkUrl?: string;
};

type AppVersionEntry = {
  android: PlatformInfo;
  ios: PlatformInfo;
  releaseNotes: string;
  isForceUpdate: boolean;
};

type AppVersionsConfig = {
  parent: AppVersionEntry;
  child: AppVersionEntry;
};

const CONFIG_PATH = join(process.cwd(), 'config', 'app-versions.json');

@Injectable()
export class AppVersionService {
  private readonly logger = new Logger(AppVersionService.name);

  private readConfig(): AppVersionsConfig {
    const raw = readFileSync(CONFIG_PATH, 'utf-8');
    return JSON.parse(raw) as AppVersionsConfig;
  }

  getVersion(app: 'parent' | 'child'): AppVersionEntry {
    try {
      const config = this.readConfig();
      const entry = config[app];
      if (!entry) {
        throw new InternalServerErrorException(
          `Config entry missing: ${app}`,
        );
      }
      return entry;
    } catch (err) {
      if (err instanceof InternalServerErrorException) throw err;
      this.logger.error('app-version: config read failed', err);
      throw new InternalServerErrorException('Configuration unavailable');
    }
  }
}
