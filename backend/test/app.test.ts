import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { createApp } from '../src/app.js';
import type { AnalysisProvider } from '../src/providers/types.js';
import { AnalyzeResponseSchema, TranslateResponseSchema } from '../src/schema.js';
import { SAFE_EN, SCAM_MOMO_EN, testConfig, TINY_PNG } from './helpers.js';

const quiet = { info: () => {}, warn: () => {}, error: () => {} };

describe('HTTP API (mock provider)', () => {
  const app = createApp({ config: testConfig(), logger: quiet });

  it('GET /healthz reports mode', async () => {
    const res = await request(app).get('/healthz');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', mode: 'mock' });
  });

  it('POST /v1/analyze returns a valid ScamAnalysis envelope', async () => {
    const res = await request(app).post('/v1/analyze').send({ message: SCAM_MOMO_EN, language: 'en' });
    expect(res.status).toBe(200);
    const body = AnalyzeResponseSchema.parse(res.body);
    expect(body.riskLevel).toBe('High');
    expect(body.language).toBe('en');
    expect(body.source).toBe('mock');
  });

  it('serves the second identical request from cache', async () => {
    const msg = `${SAFE_EN} ${Math.random()}`;
    const first = await request(app).post('/v1/analyze').send({ message: msg });
    const second = await request(app).post('/v1/analyze').send({ message: msg });
    expect(first.body.source).toBe('mock');
    expect(second.body.source).toBe('cache');
  });

  it('defaults language to en and accepts fr', async () => {
    const en = await request(app).post('/v1/analyze').send({ message: SCAM_MOMO_EN });
    const fr = await request(app).post('/v1/analyze').send({ message: SCAM_MOMO_EN, language: 'fr' });
    expect(en.body.language).toBe('en');
    expect(fr.body.language).toBe('fr');
    expect(fr.body.summary).not.toBe(en.body.summary);
  });

  it('accepts an image with or without text', async () => {
    const res = await request(app).post('/v1/analyze').send({ image: { mimeType: 'image/png', data: TINY_PNG } });
    expect(res.status).toBe(200);
    expect(res.body.riskLevel).toBeDefined();
  });

  it('rejects an empty request with 400 bad_request', async () => {
    const res = await request(app).post('/v1/analyze').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('bad_request');
    expect(res.body.error.details[0].message).toMatch(/message, an image, or both/);
  });

  it('rejects an unsupported language / mime type / non-base64 image', async () => {
    expect((await request(app).post('/v1/analyze').send({ message: 'x', language: 'de' })).status).toBe(400);
    expect((await request(app).post('/v1/analyze').send({ image: { mimeType: 'image/gif', data: TINY_PNG } })).status).toBe(400);
    expect((await request(app).post('/v1/analyze').send({ image: { mimeType: 'image/png', data: 'data:image/png;base64,AAAA' } })).status).toBe(400);
  });

  it('rejects text over MAX_TEXT_CHARS', async () => {
    const res = await request(app).post('/v1/analyze').send({ message: 'a'.repeat(2001) });
    expect(res.status).toBe(400);
  });

  it('rejects images over MAX_IMAGE_BYTES', async () => {
    const res = await request(app).post('/v1/analyze').send({ image: { mimeType: 'image/png', data: 'A'.repeat(4000) } });
    expect(res.status).toBe(400);
    expect(JSON.stringify(res.body)).toMatch(/exceeds/);
  });

  it('rejects malformed JSON bodies', async () => {
    const res = await request(app).post('/v1/analyze').set('Content-Type', 'application/json').send('{not json');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('bad_request');
  });

  it('returns 413 for oversized bodies', async () => {
    const res = await request(app).post('/v1/analyze').send({ message: 'x', pad: 'p'.repeat(200_000) });
    expect(res.status).toBe(413);
    expect(res.body.error.code).toBe('payload_too_large');
  });

  it('POST /v1/translate keeps riskLevel & confidence and tags the language', async () => {
    const analysis = { riskLevel: 'High', confidenceScore: 91, category: 'Scam', summary: 'Bad.', explanation: 'Why.', recommendedActions: ['Block.'] };
    const res = await request(app).post('/v1/translate').send({ language: 'fr', analysis });
    expect(res.status).toBe(200);
    const body = TranslateResponseSchema.parse(res.body);
    expect(body.riskLevel).toBe('High');
    expect(body.confidenceScore).toBe(91);
    expect(body.language).toBe('fr');
    expect(body.summary).toMatch(/^\[FR\] /);
  });

  it('404s unknown routes with the JSON error shape', async () => {
    const res = await request(app).get('/nope');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('not_found');
  });

  it('never exposes the Express header', async () => {
    const res = await request(app).get('/');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

describe('rate limiting', () => {
  it('returns 429 rate_limited once the window budget is spent', async () => {
    const app = createApp({ config: testConfig({ RATE_LIMIT_MAX: '2' }), logger: quiet });
    await request(app).post('/v1/analyze').send({ message: 'one' });
    await request(app).post('/v1/analyze').send({ message: 'two' });
    const third = await request(app).post('/v1/analyze').send({ message: 'three' });
    expect(third.status).toBe(429);
    expect(third.body.error.code).toBe('rate_limited');
    expect(third.headers['ratelimit-policy'] ?? third.headers['ratelimit']).toBeDefined();
    // Health is never rate-limited.
    expect((await request(app).get('/healthz')).status).toBe(200);
  });
});

describe('app token', () => {
  const app = createApp({ config: testConfig({ SABICHECK_APP_TOKEN: 's3cret' }), logger: quiet });

  it('rejects /v1 calls without the bearer token', async () => {
    const res = await request(app).post('/v1/analyze').send({ message: SCAM_MOMO_EN });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('unauthorized');
  });

  it('accepts /v1 calls with the token and leaves /healthz open', async () => {
    const ok = await request(app).post('/v1/analyze').set('Authorization', 'Bearer s3cret').send({ message: SCAM_MOMO_EN });
    expect(ok.status).toBe(200);
    expect((await request(app).get('/healthz')).status).toBe(200);
  });
});

describe('upstream failures surface as clean JSON errors', () => {
  const failing: AnalysisProvider = {
    name: 'gemini',
    async analyze() {
      return { riskLevel: 'Critical' };
    },
    async translate() {
      throw new Error('boom');
    },
  };
  const app = createApp({ config: testConfig(), provider: failing, logger: quiet });

  it('invalid model output → 502 invalid_model_output', async () => {
    const res = await request(app).post('/v1/analyze').send({ message: 'x' });
    expect(res.status).toBe(502);
    expect(res.body.error.code).toBe('invalid_model_output');
  });

  it('unexpected exceptions → 500 internal without leaking details', async () => {
    const res = await request(app)
      .post('/v1/translate')
      .send({ language: 'fr', analysis: { riskLevel: 'Low', confidenceScore: 1, category: 'c', summary: 's', explanation: 'e', recommendedActions: ['a'] } });
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('internal');
    expect(JSON.stringify(res.body)).not.toContain('boom');
  });
});
