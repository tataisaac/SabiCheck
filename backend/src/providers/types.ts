import type { Language, ScamAnalysis } from '../schema.js';

export interface ImageInput {
  mimeType: string;
  /** Raw base64, no data: prefix. */
  data: string;
}

export interface AnalyzeInput {
  message: string;
  language: Language;
  image?: ImageInput;
}

/**
 * A provider turns input into an (unvalidated) analysis. The service layer
 * validates against `ScamAnalysisSchema`, so providers may return `unknown`.
 */
export interface AnalysisProvider {
  readonly name: 'gemini' | 'mock';
  analyze(input: AnalyzeInput): Promise<unknown>;
  translate(analysis: ScamAnalysis, language: Language): Promise<unknown>;
}
