import cors from 'cors';
import express, { type NextFunction, type Request, type Response } from 'express';
import rateLimit from 'express-rate-limit';
import { ZodError } from 'zod';

import { MemoryCache } from './cache.js';
import type { AppConfig } from './config.js';
import { HttpError, unauthorized } from './errors.js';
import { GeminiProvider } from './providers/gemini.js';
import { MockProvider } from './providers/mock.js';
import type { AnalysisProvider } from './providers/types.js';
import { buildAnalyzeRequestSchema, TranslateRequestSchema, type ApiErrorBody, type ScamAnalysis } from './schema.js';
import { AnalysisService, type ServiceEvent } from './service.js';

export interface CreateAppOptions {
  config: AppConfig;
  /** Override the provider (tests inject a fake; production derives it from config). */
  provider?: AnalysisProvider;
  logger?: Pick<Console, 'info' | 'warn' | 'error'>;
}

export function createProvider(config: AppConfig): AnalysisProvider {
  if (config.mode === 'mock') return new MockProvider();
  return new GeminiProvider({
    apiKey: config.gemini.apiKey!,
    model: config.gemini.model,
    timeoutMs: config.gemini.timeoutMs,
    thinkingBudget: config.gemini.thinkingBudget,
  });
}

export function createApp({ config, provider, logger = console }: CreateAppOptions) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxy);

  const activeProvider = provider ?? createProvider(config);
  const service = new AnalysisService({
    provider: activeProvider,
    cache: new MemoryCache<ScamAnalysis>(config.cache.ttlSeconds * 1000, config.cache.maxEntries),
    onEvent: (e: ServiceEvent) => logger.info(JSON.stringify({ level: 'info', ...e })),
  });

  const AnalyzeRequestSchema = buildAnalyzeRequestSchema(config.limits);
  // JSON limit: image base64 (+33%) + text + envelope slack.
  const jsonLimit = Math.ceil(config.limits.maxImageBytes * 1.4) + config.limits.maxTextChars * 4 + 16 * 1024;

  app.use(
    cors({
      origin: config.allowedOrigins === '*' ? true : config.allowedOrigins,
      methods: ['GET', 'POST', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-App-Version', 'X-Platform'],
      maxAge: 600,
    }),
  );
  app.use(express.json({ limit: jsonLimit }));

  // ---- Public routes --------------------------------------------------------
  app.get('/', (_req, res) => {
    res.json({ name: 'SabiCheck API', version: '0.1.0', docs: '/healthz, POST /v1/analyze, POST /v1/translate' });
  });
  app.get('/healthz', (_req, res) => {
    res.json({ status: 'ok', mode: config.mode, model: config.mode === 'gemini' ? config.gemini.model : null, time: new Date().toISOString() });
  });

  // ---- /v1 (rate-limited, optionally token-gated) ---------------------------
  const v1 = express.Router();
  v1.use(
    rateLimit({
      windowMs: config.rateLimit.windowMs,
      limit: config.rateLimit.max,
      standardHeaders: 'draft-8',
      legacyHeaders: false,
      handler: (_req, res) => {
        const body: ApiErrorBody = { error: { code: 'rate_limited', message: 'Too many requests. Please wait a bit and try again.' } };
        res.status(429).json(body);
      },
    }),
  );
  if (config.appToken) {
    const expected = `Bearer ${config.appToken}`;
    v1.use((req, _res, next) => {
      const header = req.header('authorization') ?? '';
      if (!safeEqual(header, expected)) return next(unauthorized());
      next();
    });
  }

  v1.post('/analyze', async (req, res, next) => {
    try {
      const body = AnalyzeRequestSchema.parse(req.body ?? {});
      const result = await service.analyze({ message: body.message, language: body.language, image: body.image });
      res.json(result);
    } catch (err) {
      next(err);
    }
  });

  v1.post('/translate', async (req, res, next) => {
    try {
      const body = TranslateRequestSchema.parse(req.body ?? {});
      const result = await service.translate(body.analysis, body.language);
      res.json(result);
    } catch (err) {
      next(err);
    }
  });

  app.use('/v1', v1);

  // ---- 404 + error handling -------------------------------------------------
  app.use((_req, res) => {
    const body: ApiErrorBody = { error: { code: 'not_found', message: 'Route not found.' } };
    res.status(404).json(body);
  });

  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    const body = toErrorBody(err);
    if (body.status >= 500) logger.error(JSON.stringify({ level: 'error', code: body.body.error.code, message: (err as Error)?.message, stack: (err as Error)?.stack }));
    res.status(body.status).json(body.body);
  });

  return app;
}

function toErrorBody(err: unknown): { status: number; body: ApiErrorBody } {
  if (err instanceof HttpError) {
    return { status: err.status, body: { error: { code: err.code, message: err.message, ...(err.details !== undefined ? { details: err.details } : {}) } } };
  }
  if (err instanceof ZodError) {
    return {
      status: 400,
      body: { error: { code: 'bad_request', message: 'Invalid request.', details: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })) } },
    };
  }
  // body-parser errors carry `type`/`status`.
  const e = err as { type?: string; status?: number; message?: string } | undefined;
  if (e?.type === 'entity.too.large') {
    return { status: 413, body: { error: { code: 'payload_too_large', message: 'Request body is too large. Try a smaller screenshot.' } } };
  }
  if (e?.type === 'entity.parse.failed') {
    return { status: 400, body: { error: { code: 'bad_request', message: 'Body must be valid JSON.' } } };
  }
  if (typeof e?.status === 'number' && e.status >= 400 && e.status < 500) {
    return { status: e.status, body: { error: { code: 'bad_request', message: e.message ?? 'Bad request.' } } };
  }
  return { status: 500, body: { error: { code: 'internal', message: 'Something went wrong on our side. Please try again.' } } };
}

/** Constant-time string compare (avoids trivially leaking the token by timing). */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
