import type { ApiErrorCode } from './schema.js';

/** Error that maps 1:1 to an HTTP response. Anything else is a 500. */
export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: ApiErrorCode,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export const badRequest = (message: string, details?: unknown) => new HttpError(400, 'bad_request', message, details);
export const unauthorized = (message = 'Missing or invalid app token.') => new HttpError(401, 'unauthorized', message);
export const upstreamTimeout = () => new HttpError(504, 'upstream_timeout', 'The AI service took too long to respond. Please try again.');
export const upstreamError = (message = 'The AI service returned an error. Please try again.', details?: unknown) =>
  new HttpError(502, 'upstream_error', message, details);
export const invalidModelOutput = (details?: unknown) =>
  new HttpError(502, 'invalid_model_output', 'The AI returned an unexpected answer. Please try again.', details);
