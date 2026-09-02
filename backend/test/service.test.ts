import { describe, expect, it } from 'vitest';

import { MemoryCache } from '../src/cache.js';
import { HttpError } from '../src/errors.js';
import type { AnalysisProvider } from '../src/providers/types.js';
import type { ScamAnalysis } from '../src/schema.js';
import { AnalysisService, normalizeAnalysis } from '../src/service.js';

const GOOD: ScamAnalysis = {
  riskLevel: 'High',
  confidenceScore: 92,
  category: 'Mobile Money Scam',
  summary: 'Asks for PIN.',
  explanation: 'Details.',
  recommendedActions: ['Do not share your PIN.'],
};

function fakeProvider(returns: unknown[]): AnalysisProvider & { calls: number } {
  let i = 0;
  const p = {
    name: 'gemini' as const,
    calls: 0,
    async analyze() {
      p.calls++;
      return returns[Math.min(i++, returns.length - 1)];
    },
    async translate() {
      p.calls++;
      return returns[Math.min(i++, returns.length - 1)];
    },
  };
  return p;
}

describe('normalizeAnalysis', () => {
  it('accepts a clean analysis unchanged', () => {
    expect(normalizeAnalysis(GOOD)).toEqual(GOOD);
  });

  it('coerces sloppy-but-recoverable model output', () => {
    const r = normalizeAnalysis({
      ...GOOD,
      riskLevel: 'HIGH',
      confidenceScore: '87.6',
      recommendedActions: ['  Block sender ', '', 'Report', 'Verify', 'Warn family', 'Extra fifth item'],
      summary: '  padded  ',
    });
    expect(r.riskLevel).toBe('High');
    expect(r.confidenceScore).toBe(88);
    expect(r.recommendedActions).toEqual(['Block sender', 'Report', 'Verify', 'Warn family']);
    expect(r.summary).toBe('padded');
  });

  it('clamps confidence into [0,100]', () => {
    expect(normalizeAnalysis({ ...GOOD, confidenceScore: 140 }).confidenceScore).toBe(100);
    expect(normalizeAnalysis({ ...GOOD, confidenceScore: -3 }).confidenceScore).toBe(0);
  });

  it('rejects output that cannot be repaired', () => {
    expect(() => normalizeAnalysis({ ...GOOD, riskLevel: 'Critical' })).toThrow(HttpError);
    expect(() => normalizeAnalysis({ ...GOOD, recommendedActions: [] })).toThrow(HttpError);
    expect(() => normalizeAnalysis('nope')).toThrow(HttpError);
    try {
      normalizeAnalysis({ ...GOOD, summary: '' });
    } catch (e) {
      expect((e as HttpError).code).toBe('invalid_model_output');
      expect((e as HttpError).status).toBe(502);
    }
  });
});

describe('AnalysisService', () => {
  it('caches identical requests so the provider is only called once', async () => {
    const provider = fakeProvider([GOOD]);
    const svc = new AnalysisService({ provider, cache: new MemoryCache(10_000, 10) });
    const a = await svc.analyze({ message: 'send pin', language: 'en' });
    const b = await svc.analyze({ message: 'SEND  PIN', language: 'en' });
    expect(provider.calls).toBe(1);
    expect(a.source).toBe('gemini');
    expect(b.source).toBe('cache');
    expect(b.riskLevel).toBe('High');
    expect(a.analysisId).not.toBe(b.analysisId);
  });

  it('does not cache failures', async () => {
    const provider = fakeProvider([{ bad: true }, GOOD]);
    const svc = new AnalysisService({ provider, cache: new MemoryCache(10_000, 10) });
    await expect(svc.analyze({ message: 'x', language: 'en' })).rejects.toBeInstanceOf(HttpError);
    const ok = await svc.analyze({ message: 'x', language: 'en' });
    expect(ok.source).toBe('gemini');
    expect(provider.calls).toBe(2);
  });

  it('translate never lets the model change riskLevel or confidenceScore', async () => {
    const provider = fakeProvider([{ ...GOOD, riskLevel: 'Low', confidenceScore: 10, summary: 'Demande le PIN.' }]);
    const svc = new AnalysisService({ provider, cache: new MemoryCache(0, 0) });
    const r = await svc.translate(GOOD, 'fr');
    expect(r.riskLevel).toBe('High');
    expect(r.confidenceScore).toBe(92);
    expect(r.summary).toBe('Demande le PIN.');
    expect(r.language).toBe('fr');
  });

  it('emits events without message content', async () => {
    const events: unknown[] = [];
    const svc = new AnalysisService({ provider: fakeProvider([GOOD]), cache: new MemoryCache(0, 0), onEvent: (e) => events.push(e) });
    await svc.analyze({ message: 'secret content here', language: 'fr' });
    expect(events).toHaveLength(1);
    expect(JSON.stringify(events[0])).not.toContain('secret content');
    expect(events[0]).toMatchObject({ type: 'analyze', language: 'fr', hasImage: false, textChars: 19 });
  });
});
