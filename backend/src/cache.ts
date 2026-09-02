import { createHash } from 'node:crypto';

/**
 * Tiny in-memory TTL + LRU cache. Good enough for a single Cloud Run / VM
 * instance; swap for Redis/Firestore behind the same interface when there are
 * multiple instances.
 */
export interface Cache<V> {
  get(key: string): V | undefined;
  set(key: string, value: V): void;
  size(): number;
  clear(): void;
}

interface Entry<V> {
  value: V;
  expiresAt: number;
}

export class MemoryCache<V> implements Cache<V> {
  private readonly map = new Map<string, Entry<V>>();

  constructor(
    private readonly ttlMs: number,
    private readonly maxEntries: number,
    private readonly now: () => number = Date.now,
  ) {}

  get(key: string): V | undefined {
    if (this.ttlMs <= 0 || this.maxEntries <= 0) return undefined;
    const entry = this.map.get(key);
    if (!entry) return undefined;
    if (entry.expiresAt <= this.now()) {
      this.map.delete(key);
      return undefined;
    }
    // Refresh recency (Map preserves insertion order → delete + re-insert = LRU touch).
    this.map.delete(key);
    this.map.set(key, entry);
    return entry.value;
  }

  set(key: string, value: V): void {
    if (this.ttlMs <= 0 || this.maxEntries <= 0) return;
    if (this.map.has(key)) this.map.delete(key);
    this.map.set(key, { value, expiresAt: this.now() + this.ttlMs });
    while (this.map.size > this.maxEntries) {
      const oldest = this.map.keys().next().value;
      if (oldest === undefined) break;
      this.map.delete(oldest);
    }
  }

  size(): number {
    return this.map.size;
  }

  clear(): void {
    this.map.clear();
  }
}

/** Stable cache key: identical input + language → identical key. Never stores raw content. */
export function analysisCacheKey(input: { message: string; language: string; image?: { mimeType: string; data: string } }): string {
  const h = createHash('sha256');
  h.update(input.language);
  h.update('\u0000');
  h.update(input.message.trim().replace(/\s+/g, ' ').toLowerCase());
  h.update('\u0000');
  if (input.image) {
    h.update(input.image.mimeType);
    h.update('\u0000');
    h.update(input.image.data);
  }
  return h.digest('hex');
}
