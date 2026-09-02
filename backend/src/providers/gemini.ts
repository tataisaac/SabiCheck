import {
  ApiError,
  GoogleGenAI,
  Type,
  createPartFromBase64,
  createPartFromText,
  createUserContent,
  type Content,
  type GenerateContentConfig,
  type Schema,
} from '@google/genai';

import { invalidModelOutput, upstreamError, upstreamTimeout } from '../errors.js';
import { buildAnalysisPrompt, buildTranslateAnalysisPrompt } from '../prompts.js';
import type { Language, ScamAnalysis } from '../schema.js';
import type { AnalysisProvider, AnalyzeInput } from './types.js';

/** Structured-output schema. Mirrors the reference web app exactly (spec §5.1). */
export const SCAM_ANALYSIS_RESPONSE_SCHEMA: Schema = {
  type: Type.OBJECT,
  properties: {
    riskLevel: {
      type: Type.STRING,
      enum: ['Low', 'Medium', 'High'],
      description: 'The assessed risk level of the message. Low = Safe/Normal, Medium = Suspicious, High = Definite Scam.',
    },
    confidenceScore: {
      type: Type.INTEGER,
      description: "Confidence score of the AI's assessment, from 0 to 100.",
    },
    category: {
      type: Type.STRING,
      description: 'The category or threat type (e.g., Mobile Money Scam, WhatsApp Impersonation, Phishing, Safe).',
    },
    summary: {
      type: Type.STRING,
      description: 'A concise 1-2 sentence summary of the suspicious indicators.',
    },
    explanation: {
      type: Type.STRING,
      description: 'A detailed explanation of all the suspicious indicators detected in the message.',
    },
    recommendedActions: {
      type: Type.ARRAY,
      items: { type: Type.STRING },
      description: 'A list of 1 to 4 concise, actionable bullet points on what the user should do next.',
    },
  },
  required: ['riskLevel', 'confidenceScore', 'category', 'summary', 'explanation', 'recommendedActions'],
  propertyOrdering: ['riskLevel', 'confidenceScore', 'category', 'summary', 'explanation', 'recommendedActions'],
};

export interface GeminiProviderOptions {
  apiKey: string;
  model: string;
  timeoutMs: number;
  thinkingBudget?: number | undefined;
}

/** Minimal surface of the SDK we depend on — lets tests inject a fake without network. */
export interface GenerateContentLike {
  generateContent(params: {
    model: string;
    contents: Content;
    config?: GenerateContentConfig;
  }): Promise<{ text: string | undefined; promptFeedback?: { blockReason?: unknown } }>;
}

export class GeminiProvider implements AnalysisProvider {
  readonly name = 'gemini' as const;
  private readonly models: GenerateContentLike;

  constructor(
    private readonly opts: GeminiProviderOptions,
    models?: GenerateContentLike,
  ) {
    this.models =
      models ??
      new GoogleGenAI({
        apiKey: opts.apiKey,
        httpOptions: { timeout: opts.timeoutMs },
      }).models;
  }

  async analyze(input: AnalyzeInput): Promise<unknown> {
    const parts = [createPartFromText(buildAnalysisPrompt(input.language, input.message))];
    if (input.image) {
      parts.push(createPartFromBase64(input.image.data, input.image.mimeType));
    }
    return this.generateJson(createUserContent(parts));
  }

  async translate(analysis: ScamAnalysis, language: Language): Promise<unknown> {
    return this.generateJson(createUserContent(buildTranslateAnalysisPrompt(language, analysis)));
  }

  private async generateJson(contents: Content): Promise<unknown> {
    const config: GenerateContentConfig = {
      responseMimeType: 'application/json',
      responseSchema: SCAM_ANALYSIS_RESPONSE_SCHEMA,
      temperature: 0.2,
    };
    if (this.opts.thinkingBudget !== undefined) {
      config.thinkingConfig = { thinkingBudget: this.opts.thinkingBudget };
    }

    let response: Awaited<ReturnType<GenerateContentLike['generateContent']>>;
    try {
      response = await this.models.generateContent({ model: this.opts.model, contents, config });
    } catch (err) {
      throw mapSdkError(err);
    }

    const text = response.text;
    if (!text) {
      const blockReason = response.promptFeedback?.blockReason;
      throw invalidModelOutput({ reason: 'empty_response', blockReason });
    }
    try {
      return JSON.parse(text) as unknown;
    } catch {
      throw invalidModelOutput({ reason: 'not_json' });
    }
  }
}

function mapSdkError(err: unknown): Error {
  if (err instanceof ApiError) {
    if (err.status === 429) return upstreamError('The AI service is busy (quota exceeded). Please try again shortly.', { status: 429 });
    if (err.status === 408 || err.status === 504) return upstreamTimeout();
    return upstreamError(undefined, { status: err.status });
  }
  if (err instanceof Error) {
    const name = err.name.toLowerCase();
    const msg = err.message.toLowerCase();
    if (name.includes('abort') || name.includes('timeout') || msg.includes('timed out') || msg.includes('timeout')) {
      return upstreamTimeout();
    }
    return upstreamError(undefined, { message: err.message });
  }
  return upstreamError();
}
