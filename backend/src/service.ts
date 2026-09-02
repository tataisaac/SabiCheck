import { randomUUID } from 'node:crypto';

import { analysisCacheKey, type Cache } from './cache.js';
import { invalidModelOutput } from './errors.js';
import type { AnalysisProvider, AnalyzeInput } from './providers/types.js';
import { ScamAnalysisSchema, type AnalyzeResponse, type Language, type ScamAnalysis, type TranslateResponse } from './schema.js';

export interface AnalysisServiceDeps {
  provider: AnalysisProvider;
  cache: Cache<ScamAnalysis>;
  /** Optional hook for logging/metrics. Never receives message content. */
  onEvent?: (event: ServiceEvent) => void;
}

export type ServiceEvent =
  | { type: 'analyze'; source: 'cache' | 'gemini' | 'mock'; language: Language; hasImage: boolean; textChars: number; ms: number }
  | { type: 'translate'; source: 'cache' | 'gemini' | 'mock'; language: Language; ms: number };

/** Coerce + validate whatever a provider returned into a strict ScamAnalysis. */
export function normalizeAnalysis(raw: unknown): ScamAnalysis {
  const candidate = coerce(raw);
  const parsed = ScamAnalysisSchema.safeParse(candidate);
  if (!parsed.success) {
    throw invalidModelOutput({ issues: parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`) });
  }
  return parsed.data;
}

function coerce(raw: unknown): unknown {
  if (!raw || typeof raw !== 'object') return raw;
  const r = { ...(raw as Record<string, unknown>) };

  // Models occasionally return "85" or 85.4 — clamp to an int in [0, 100].
  if (typeof r.confidenceScore === 'string' && r.confidenceScore.trim() !== '') r.confidenceScore = Number(r.confidenceScore);
  if (typeof r.confidenceScore === 'number' && Number.isFinite(r.confidenceScore)) {
    r.confidenceScore = Math.max(0, Math.min(100, Math.round(r.confidenceScore)));
  }

  // Normalise riskLevel casing ("high" → "High", "HIGH" → "High").
  if (typeof r.riskLevel === 'string') {
    const v = r.riskLevel.trim().toLowerCase();
    r.riskLevel = v === 'low' ? 'Low' : v === 'medium' ? 'Medium' : v === 'high' ? 'High' : r.riskLevel;
  }

  // recommendedActions: accept a single string, drop blanks, cap at 4.
  if (typeof r.recommendedActions === 'string') r.recommendedActions = [r.recommendedActions];
  if (Array.isArray(r.recommendedActions)) {
    r.recommendedActions = r.recommendedActions
      .filter((a): a is string => typeof a === 'string' && a.trim().length > 0)
      .map((a) => a.trim())
      .slice(0, 4);
  }
  for (const k of ['category', 'summary', 'explanation'] as const) {
    if (typeof r[k] === 'string') r[k] = (r[k] as string).trim();
  }
  return r;
}

export class AnalysisService {
  constructor(private readonly deps: AnalysisServiceDeps) {}

  async analyze(input: AnalyzeInput): Promise<AnalyzeResponse> {
    const started = Date.now();
    const key = analysisCacheKey(input);
    const cached = this.deps.cache.get(key);
    if (cached) {
      this.emit({ type: 'analyze', source: 'cache', language: input.language, hasImage: !!input.image, textChars: input.message.length, ms: Date.now() - started });
      return { ...cached, language: input.language, source: 'cache', analysisId: randomUUID() };
    }

    const raw = await this.deps.provider.analyze(input);
    const analysis = normalizeAnalysis(raw);
    this.deps.cache.set(key, analysis);
    this.emit({ type: 'analyze', source: this.deps.provider.name, language: input.language, hasImage: !!input.image, textChars: input.message.length, ms: Date.now() - started });
    return { ...analysis, language: input.language, source: this.deps.provider.name, analysisId: randomUUID() };
  }

  async translate(analysis: ScamAnalysis, language: Language): Promise<TranslateResponse> {
    const started = Date.now();
    const key = analysisCacheKey({ message: `translate:${JSON.stringify(analysis)}`, language });
    const cached = this.deps.cache.get(key);
    if (cached) {
      this.emit({ type: 'translate', source: 'cache', language, ms: Date.now() - started });
      return { ...cached, language, source: 'cache' };
    }

    const raw = await this.deps.provider.translate(analysis, language);
    const translated = normalizeAnalysis(raw);
    // Hard guarantees from spec §5.3, regardless of what the model did.
    const result: ScamAnalysis = { ...translated, riskLevel: analysis.riskLevel, confidenceScore: analysis.confidenceScore };
    this.deps.cache.set(key, result);
    this.emit({ type: 'translate', source: this.deps.provider.name, language, ms: Date.now() - started });
    return { ...result, language, source: this.deps.provider.name };
  }

  private emit(event: ServiceEvent) {
    try {
      this.deps.onEvent?.(event);
    } catch {
      /* logging must never break a request */
    }
  }
}
