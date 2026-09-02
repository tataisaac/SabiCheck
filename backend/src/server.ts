import { createApp } from './app.js';
import { ConfigError, loadConfig } from './config.js';

// Load a local .env in development without adding a dependency (Node ≥ 20.12).
try {
  process.loadEnvFile?.('.env');
} catch {
  /* no .env file — fine (Cloud Run / CI inject real env vars) */
}

let config;
try {
  config = loadConfig();
} catch (err) {
  if (err instanceof ConfigError) {
    console.error(`[sabicheck-api] ${err.message}`);
    process.exit(1);
  }
  throw err;
}

const app = createApp({ config });
const server = app.listen(config.port, '0.0.0.0', () => {
  console.log(
    JSON.stringify({ level: 'info', msg: 'listening', port: config.port, mode: config.mode, model: config.mode === 'gemini' ? config.gemini.model : null }),
  );
});

const shutdown = (signal: string) => {
  console.log(JSON.stringify({ level: 'info', msg: 'shutting down', signal }));
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000).unref();
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
