import { describe, expect, it } from 'vitest';

import { ConfigError, loadConfig } from '../src/config.js';

describe('loadConfig', () => {
  it('refuses to start in gemini mode without an API key', () => {
    expect(() => loadConfig({})).toThrow(ConfigError);
    expect(() => loadConfig({ SABICHECK_MODE: 'gemini' })).toThrow(/GEMINI_API_KEY/);
  });

  it('allows mock mode with no key', () => {
    const c = loadConfig({ SABICHECK_MODE: 'mock' });
    expect(c.mode).toBe('mock');
    expect(c.gemini.apiKey).toBeUndefined();
  });

  it('defaults to gemini mode when a key is present', () => {
    const c = loadConfig({ GEMINI_API_KEY: 'k' });
    expect(c.mode).toBe('gemini');
    expect(c.gemini.model).toBe('gemini-2.5-flash');
    expect(c.port).toBe(8080);
  });

  it('parses numeric and list settings', () => {
    const c = loadConfig({
      SABICHECK_MODE: 'mock',
      PORT: '9000',
      ALLOWED_ORIGINS: 'https://a.example, https://b.example',
      RATE_LIMIT_MAX: '5',
      GEMINI_THINKING_BUDGET: '0',
      TRUST_PROXY: 'false',
    });
    expect(c.port).toBe(9000);
    expect(c.allowedOrigins).toEqual(['https://a.example', 'https://b.example']);
    expect(c.rateLimit.max).toBe(5);
    expect(c.gemini.thinkingBudget).toBe(0);
    expect(c.trustProxy).toBe(false);
  });

  it('rejects garbage values with a readable error', () => {
    expect(() => loadConfig({ SABICHECK_MODE: 'mock', PORT: 'abc' })).toThrow(/PORT/);
    expect(() => loadConfig({ SABICHECK_MODE: 'banana' })).toThrow(ConfigError);
  });
});
