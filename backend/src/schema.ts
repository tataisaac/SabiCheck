/**
 * Shared request/response contracts for the SabiCheck API.
 *
 * `ScamAnalysis` is THE contract between the backend and every client
 * (Flutter mobile/web, the legacy React app). It mirrors SABICHECK_SPEC.md §5.1
 * exactly, plus two additive, non-breaking fields (`language`, `source`) so
 * clients can tell where an answer came from.
 */
import { z } from 'zod';

export const LANGUAGES = ['en', 'fr'] as const;
export type Language = (typeof LANGUAGES)[number];

export const RISK_LEVELS = ['Low', 'Medium', 'High'] as const;
export type RiskLevel = (typeof RISK_LEVELS)[number];

export const IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'] as const;

/** The core verdict returned to clients. Field names are frozen — do not rename. */
export const ScamAnalysisSchema = z.object({
  riskLevel: z.enum(RISK_LEVELS),
  confidenceScore: z.number().int().min(0).max(100),
  category: z.string().min(1),
  summary: z.string().min(1),
  explanation: z.string().min(1),
  recommendedActions: z.array(z.string().min(1)).min(1).max(4),
});
export type ScamAnalysis = z.infer<typeof ScamAnalysisSchema>;

export const AnalysisSourceSchema = z.enum(['gemini', 'mock', 'cache']);
export type AnalysisSource = z.infer<typeof AnalysisSourceSchema>;

/** Response envelope for POST /v1/analyze. */
export const AnalyzeResponseSchema = ScamAnalysisSchema.extend({
  language: z.enum(LANGUAGES),
  source: AnalysisSourceSchema,
  /** Server-side ID of this verdict. Reserved for future "report a scam" flows. */
  analysisId: z.string().min(1),
});
export type AnalyzeResponse = z.infer<typeof AnalyzeResponseSchema>;

/**
 * Factory so the max sizes can come from runtime config while the shape stays
 * a single source of truth.
 */
export function buildAnalyzeRequestSchema(limits: { maxTextChars: number; maxImageBytes: number }) {
  // base64 inflates size by 4/3; give the string budget accordingly.
  const maxBase64Chars = Math.ceil((limits.maxImageBytes * 4) / 3) + 4;

  return z
    .object({
      message: z.string().trim().max(limits.maxTextChars).optional().default(''),
      language: z.enum(LANGUAGES).optional().default('en'),
      image: z
        .object({
          mimeType: z.enum(IMAGE_MIME_TYPES),
          /** Raw base64 (no `data:` prefix). */
          data: z
            .string()
            .min(1)
            .max(maxBase64Chars, { message: `image exceeds ${limits.maxImageBytes} bytes` })
            .regex(/^[A-Za-z0-9+/]+={0,2}$/, { message: 'image.data must be plain base64' }),
        })
        .optional(),
    })
    .refine((v) => v.message.length > 0 || v.image !== undefined, {
      message: 'Provide a message, an image, or both.',
      path: ['message'],
    });
}
export type AnalyzeRequest = z.infer<ReturnType<typeof buildAnalyzeRequestSchema>>;

/** POST /v1/translate — translate an existing analysis into the other language. */
export const TranslateRequestSchema = z.object({
  language: z.enum(LANGUAGES),
  analysis: ScamAnalysisSchema,
});
export type TranslateRequest = z.infer<typeof TranslateRequestSchema>;

export const TranslateResponseSchema = ScamAnalysisSchema.extend({
  language: z.enum(LANGUAGES),
  source: AnalysisSourceSchema,
});
export type TranslateResponse = z.infer<typeof TranslateResponseSchema>;

/** Uniform error body. `code` is stable and machine-readable; `message` is for humans. */
export const ApiErrorSchema = z.object({
  error: z.object({
    code: z.enum([
      'bad_request',
      'unauthorized',
      'payload_too_large',
      'rate_limited',
      'upstream_error',
      'upstream_timeout',
      'invalid_model_output',
      'not_found',
      'internal',
    ]),
    message: z.string(),
    details: z.unknown().optional(),
  }),
});
export type ApiErrorBody = z.infer<typeof ApiErrorSchema>;
export type ApiErrorCode = ApiErrorBody['error']['code'];
