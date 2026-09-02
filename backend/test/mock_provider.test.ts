import { describe, expect, it } from 'vitest';

import { mockAnalyze } from '../src/providers/mock.js';
import { ScamAnalysisSchema } from '../src/schema.js';
import { SAFE_EN, SCAM_MOMO_EN } from './helpers.js';

describe('mockAnalyze', () => {
  it('flags an obvious MoMo prize/PIN scam as High risk', () => {
    const r = mockAnalyze({ message: SCAM_MOMO_EN, language: 'en' });
    expect(ScamAnalysisSchema.parse(r)).toBeTruthy();
    expect(r.riskLevel).toBe('High');
    expect(r.confidenceScore).toBeGreaterThanOrEqual(60);
    expect(r.recommendedActions.length).toBeGreaterThan(0);
    expect(r.recommendedActions.length).toBeLessThanOrEqual(4);
  });

  it('marks a normal message as Low risk', () => {
    const r = mockAnalyze({ message: SAFE_EN, language: 'en' });
    expect(r.riskLevel).toBe('Low');
  });

  it('answers in French when asked', () => {
    const r = mockAnalyze({
      message: 'Félicitations ! Vous avez gagné 100 000 FCFA. Envoyez votre code PIN Orange Money immédiatement.',
      language: 'fr',
    });
    expect(r.riskLevel).toBe('High');
    expect(r.summary).toMatch(/arnaque/i);
    expect(r.recommendedActions[0]).toMatch(/argent|PIN/i);
  });

  it('handles image-only input without crashing', () => {
    const r = mockAnalyze({ message: '', language: 'en', image: { mimeType: 'image/png', data: 'AAAA' } });
    expect(ScamAnalysisSchema.parse(r)).toBeTruthy();
    expect(r.explanation).toMatch(/screenshot/i);
  });

  it('is deterministic', () => {
    const a = mockAnalyze({ message: SCAM_MOMO_EN, language: 'en' });
    const b = mockAnalyze({ message: SCAM_MOMO_EN, language: 'en' });
    expect(a).toEqual(b);
  });
});
