import { describe, expect, it } from 'vitest';

import { analysisCacheKey, MemoryCache } from '../src/cache.js';

describe('MemoryCache', () => {
  it('stores and expires entries by TTL', () => {
    let now = 1_000;
    const cache = new MemoryCache<string>(100, 10, () => now);
    cache.set('a', 'A');
    expect(cache.get('a')).toBe('A');
    now += 99;
    expect(cache.get('a')).toBe('A');
    now += 2;
    expect(cache.get('a')).toBeUndefined();
    expect(cache.size()).toBe(0);
  });

  it('evicts least-recently-used entries beyond maxEntries', () => {
    const cache = new MemoryCache<number>(10_000, 2);
    cache.set('a', 1);
    cache.set('b', 2);
    cache.get('a'); // touch a → b is now oldest
    cache.set('c', 3);
    expect(cache.get('b')).toBeUndefined();
    expect(cache.get('a')).toBe(1);
    expect(cache.get('c')).toBe(3);
  });

  it('is a no-op when disabled (ttl 0 or max 0)', () => {
    const off = new MemoryCache<number>(0, 10);
    off.set('a', 1);
    expect(off.get('a')).toBeUndefined();
    const off2 = new MemoryCache<number>(1000, 0);
    off2.set('a', 1);
    expect(off2.get('a')).toBeUndefined();
  });
});

describe('analysisCacheKey', () => {
  it('is stable across whitespace/case differences and distinct per language', () => {
    const a = analysisCacheKey({ message: 'Send  your PIN now', language: 'en' });
    const b = analysisCacheKey({ message: 'send your pin NOW ', language: 'en' });
    const c = analysisCacheKey({ message: 'Send your PIN now', language: 'fr' });
    expect(a).toBe(b);
    expect(a).not.toBe(c);
    expect(a).toMatch(/^[0-9a-f]{64}$/);
  });

  it('includes the image in the key', () => {
    const noImg = analysisCacheKey({ message: 'x', language: 'en' });
    const img = analysisCacheKey({ message: 'x', language: 'en', image: { mimeType: 'image/png', data: 'AAAA' } });
    const img2 = analysisCacheKey({ message: 'x', language: 'en', image: { mimeType: 'image/png', data: 'BBBB' } });
    expect(noImg).not.toBe(img);
    expect(img).not.toBe(img2);
  });
});
