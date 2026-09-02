import { ApiError } from '@google/genai';
import { describe, expect, it } from 'vitest';

import { HttpError } from '../src/errors.js';
import { GeminiProvider, SCAM_ANALYSIS_RESPONSE_SCHEMA, type GenerateContentLike } from '../src/providers/gemini.js';

const OPTS = { apiKey: 'test', model: 'gemini-2.5-flash', timeoutMs: 1000, thinkingBudget: 0 };

function fakeModels(impl: GenerateContentLike['generateContent']): GenerateContentLike & { last?: Parameters<GenerateContentLike['generateContent']>[0] } {
  const m: GenerateContentLike & { last?: Parameters<GenerateContentLike['generateContent']>[0] } = {
    async generateContent(params) {
      m.last = params;
      return impl(params);
    },
  };
  return m;
}

describe('GeminiProvider', () => {
  it('sends a structured-output request with the SabiCheck prompt and parses JSON', async () => {
    const models = fakeModels(async () => ({ text: JSON.stringify({ riskLevel: 'High', confidenceScore: 90, category: 'x', summary: 's', explanation: 'e', recommendedActions: ['a'] }) }));
    const p = new GeminiProvider(OPTS, models);

    const out = (await p.analyze({ message: 'send me your PIN', language: 'fr' })) as { riskLevel: string };
    expect(out.riskLevel).toBe('High');

    const req = models.last!;
    expect(req.model).toBe('gemini-2.5-flash');
    expect(req.config?.responseMimeType).toBe('application/json');
    expect(req.config?.responseSchema).toBe(SCAM_ANALYSIS_RESPONSE_SCHEMA);
    expect(req.config?.thinkingConfig).toEqual({ thinkingBudget: 0 });

    const parts = req.contents.parts ?? [];
    expect(parts).toHaveLength(1);
    const text = parts[0]?.text ?? '';
    expect(text).toContain('You are SabiCheck');
    expect(text).toContain('respond entirely in French');
    expect(text).toContain('send me your PIN');
    expect(text).not.toContain('ScamShield');
  });

  it('attaches an image as an inline base64 part', async () => {
    const models = fakeModels(async () => ({ text: '{}' }));
    const p = new GeminiProvider(OPTS, models);
    await p.analyze({ message: '', language: 'en', image: { mimeType: 'image/png', data: 'AAAA' } });
    const parts = models.last!.contents.parts ?? [];
    expect(parts).toHaveLength(2);
    expect(parts[1]?.inlineData).toEqual({ data: 'AAAA', mimeType: 'image/png' });
  });

  it('omits thinkingConfig when no budget configured', async () => {
    const models = fakeModels(async () => ({ text: '{}' }));
    const p = new GeminiProvider({ ...OPTS, thinkingBudget: undefined }, models);
    await p.analyze({ message: 'hi', language: 'en' });
    expect(models.last!.config?.thinkingConfig).toBeUndefined();
  });

  it('maps empty / blocked responses to invalid_model_output', async () => {
    const p = new GeminiProvider(OPTS, fakeModels(async () => ({ text: undefined, promptFeedback: { blockReason: 'SAFETY' } })));
    await expect(p.analyze({ message: 'x', language: 'en' })).rejects.toMatchObject({ code: 'invalid_model_output', status: 502 });
  });

  it('maps non-JSON text to invalid_model_output', async () => {
    const p = new GeminiProvider(OPTS, fakeModels(async () => ({ text: 'Sure! Here is the analysis:' })));
    await expect(p.analyze({ message: 'x', language: 'en' })).rejects.toMatchObject({ code: 'invalid_model_output' });
  });

  it('maps SDK ApiError 429 to upstream_error with a quota message', async () => {
    const p = new GeminiProvider(OPTS, fakeModels(async () => { throw new ApiError({ status: 429, message: 'quota' }); }));
    const err = await p.analyze({ message: 'x', language: 'en' }).catch((e) => e as HttpError);
    expect(err).toBeInstanceOf(HttpError);
    expect(err.code).toBe('upstream_error');
    expect(err.message).toMatch(/busy|quota/i);
  });

  it('maps timeouts to upstream_timeout (504)', async () => {
    const p = new GeminiProvider(OPTS, fakeModels(async () => { const e = new Error('The operation was aborted'); e.name = 'AbortError'; throw e; }));
    await expect(p.analyze({ message: 'x', language: 'en' })).rejects.toMatchObject({ code: 'upstream_timeout', status: 504 });
  });

  it('translate sends the translation prompt with the JSON embedded', async () => {
    const models = fakeModels(async () => ({ text: '{}' }));
    const p = new GeminiProvider(OPTS, models);
    await p.translate({ riskLevel: 'Low', confidenceScore: 70, category: 'Safe', summary: 's', explanation: 'e', recommendedActions: ['a'] }, 'fr');
    const text = models.last!.contents.parts?.[0]?.text ?? '';
    expect(text).toContain('into French');
    expect(text).toContain('"riskLevel": "Low"');
    expect(text).toContain('DO NOT translate the \'riskLevel\'');
  });
});
