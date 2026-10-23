// A tiny relay so the app can use Groq without the person typing a key.
// The real key stays here; the app only knows APP_TOKEN. No dependencies, Node 18+.
//   GROQ_API_KEY=gsk_...  APP_TOKEN=<long random string>  node server.js
// The app is built with:  --dart-define=AI_PROXY_URL=https://<your host>/v1 --dart-define=AI_PROXY_TOKEN=<APP_TOKEN>
const http = require('http');

const { GROQ_API_KEY, APP_TOKEN, PORT = 3000 } = process.env;
if (!GROQ_API_KEY || !APP_TOKEN) {
  console.error('Set GROQ_API_KEY and APP_TOKEN');
  process.exit(1);
}

const ALLOWED = new Set(['/v1/chat/completions', '/v1/audio/transcriptions']);
const MAX_BODY = 12 * 1024 * 1024; // a receipt photo or a short voice note
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 30;
const hits = new Map();

function limited(ip) {
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < WINDOW_MS);
  recent.push(now);
  hits.set(ip, recent);
  return recent.length > MAX_PER_WINDOW;
}

http
  .createServer(async (req, res) => {
    const send = (code, text) => {
      res.writeHead(code, { 'Content-Type': 'text/plain' });
      res.end(text);
    };
    const path = (req.url || '').split('?')[0];
    if (req.method !== 'POST' || !ALLOWED.has(path)) return send(404, 'not found');
    if (req.headers.authorization !== `Bearer ${APP_TOKEN}`) return send(401, 'unauthorized');
    if (limited(req.socket.remoteAddress || '')) return send(429, 'slow down');

    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > MAX_BODY) return send(413, 'too large');
      chunks.push(chunk);
    }
    try {
      const upstream = await fetch(`https://api.groq.com/openai${path}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${GROQ_API_KEY}`,
          'Content-Type': req.headers['content-type'] || 'application/json',
        },
        body: Buffer.concat(chunks),
      });
      res.writeHead(upstream.status, { 'Content-Type': upstream.headers.get('content-type') || 'application/json' });
      res.end(Buffer.from(await upstream.arrayBuffer()));
    } catch {
      send(502, 'upstream failed');
    }
  })
  .listen(PORT, () => console.log(`ai-proxy on ${PORT}`));
