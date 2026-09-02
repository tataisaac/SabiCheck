import { z } from 'zod';

const intFromEnv = (fallback: number, min = 0) =>
  z
    .string()
    .optional()
    .transform((v) => (v === undefined || v.trim() === '' ? fallback : Number(v)))
    .pipe(z.number().int().min(min));

const EnvSchema = z.object({
  PORT: intFromEnv(8080, 1),
  SABICHECK_MODE: z.enum(['gemini', 'mock']).optional(),
  GEMINI_API_KEY: z.string().optional(),
  GEMINI_MODEL: z.string().optional().transform((v) => (v && v.trim() ? v.trim() : 'gemini-2.5-flash')),
  GEMINI_THINKING_BUDGET: z
    .string()
    .optional()
    .transform((v) => (v === undefined || v.trim() === '' ? undefined : Number(v)))
    .pipe(z.number().int().min(0).optional()),
  GEMINI_TIMEOUT_MS: intFromEnv(30_000, 1_000),
  SABICHECK_APP_TOKEN: z.string().optional().transform((v) => (v && v.trim() ? v.trim() : undefined)),
  ALLOWED_ORIGINS: z.string().optional().transform((v) => (v && v.trim() ? v.trim() : '*')),
  RATE_LIMIT_WINDOW_MS: intFromEnv(15 * 60_000, 1_000),
  RATE_LIMIT_MAX: intFromEnv(30, 1),
  MAX_TEXT_CHARS: intFromEnv(8_000, 1),
  MAX_IMAGE_BYTES: intFromEnv(5 * 1024 * 1024, 1),
  CACHE_TTL_SECONDS: intFromEnv(24 * 3600, 0),
  CACHE_MAX_ENTRIES: intFromEnv(500, 0),
  TRUST_PROXY: z.string().optional().transform((v) => (v && v.trim() ? v.trim() : '1')),
});

export interface AppConfig {
  port: number;
  mode: 'gemini' | 'mock';
  gemini: {
    apiKey: string | undefined;
    model: string;
    thinkingBudget: number | undefined;
    timeoutMs: number;
  };
  appToken: string | undefined;
  allowedOrigins: '*' | string[];
  rateLimit: { windowMs: number; max: number };
  limits: { maxTextChars: number; maxImageBytes: number };
  cache: { ttlSeconds: number; maxEntries: number };
  trustProxy: boolean | number | string;
}

export class ConfigError extends Error {}

/**
 * Build a validated config from an env-like record. Pure, so tests can pass
 * their own env instead of mutating `process.env`.
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = EnvSchema.safeParse(env);
  if (!parsed.success) {
    throw new ConfigError(`Invalid environment: ${parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ')}`);
  }
  const e = parsed.data;

  const hasKey = Boolean(e.GEMINI_API_KEY && e.GEMINI_API_KEY.trim());
  const mode: 'gemini' | 'mock' = e.SABICHECK_MODE ?? (hasKey ? 'gemini' : 'gemini');
  if (mode === 'gemini' && !hasKey) {
    throw new ConfigError(
      'GEMINI_API_KEY is not set. Provide a key, or set SABICHECK_MODE=mock for local development without AI.',
    );
  }

  const allowedOrigins: '*' | string[] =
    e.ALLOWED_ORIGINS === '*'
      ? '*'
      : e.ALLOWED_ORIGINS.split(',')
          .map((s) => s.trim())
          .filter(Boolean);

  const trustProxyRaw = e.TRUST_PROXY;
  const trustProxy: boolean | number | string =
    trustProxyRaw === 'true' ? true : trustProxyRaw === 'false' ? false : /^\d+$/.test(trustProxyRaw) ? Number(trustProxyRaw) : trustProxyRaw;

  return {
    port: e.PORT,
    mode,
    gemini: {
      apiKey: hasKey ? e.GEMINI_API_KEY!.trim() : undefined,
      model: e.GEMINI_MODEL,
      thinkingBudget: e.GEMINI_THINKING_BUDGET,
      timeoutMs: e.GEMINI_TIMEOUT_MS,
    },
    appToken: e.SABICHECK_APP_TOKEN,
    allowedOrigins,
    rateLimit: { windowMs: e.RATE_LIMIT_WINDOW_MS, max: e.RATE_LIMIT_MAX },
    limits: { maxTextChars: e.MAX_TEXT_CHARS, maxImageBytes: e.MAX_IMAGE_BYTES },
    cache: { ttlSeconds: e.CACHE_TTL_SECONDS, maxEntries: e.CACHE_MAX_ENTRIES },
    trustProxy,
  };
}
