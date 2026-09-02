import { loadConfig, type AppConfig } from '../src/config.js';

/** Config for tests: mock mode, generous rate limit, tiny cache TTL unless overridden. */
export function testConfig(overrides: Partial<NodeJS.ProcessEnv> = {}): AppConfig {
  return loadConfig({
    SABICHECK_MODE: 'mock',
    RATE_LIMIT_MAX: '1000',
    RATE_LIMIT_WINDOW_MS: '60000',
    MAX_TEXT_CHARS: '2000',
    MAX_IMAGE_BYTES: '1024',
    CACHE_TTL_SECONDS: '60',
    CACHE_MAX_ENTRIES: '50',
    ...overrides,
  });
}

/** 1x1 transparent PNG, base64. */
export const TINY_PNG =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

export const SCAM_MOMO_EN =
  'Congratulations! Your MTN MoMo account has won 500,000 FCFA. To receive it, send your PIN and 2,000 FCFA activation fee to 6XX XXX XXX urgently before it expires.';
export const SAFE_EN = 'Hi, are we still meeting at the church hall tomorrow at 10?';
