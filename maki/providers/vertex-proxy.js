#!/usr/bin/env node
'use strict';
// Signature-preserving proxy between Maki and Vertex AI's native Gemini endpoint.
//
// Gemini 3.x attaches an encrypted `thoughtSignature` to every functionCall it
// returns, and *requires* that signature echoed back on the next turn or it 400s
// ("Function call is missing a thought_signature"). Maki's providers don't carry
// that field across turns, so multi-turn tool calls break.
//
// This proxy sits in the middle (Maki -> here -> Vertex). It:
//   * captures `thoughtSignature` from each functionCall in responses, and
//   * re-injects it into functionCall parts of later requests that lack one.
//
// Maki never has to know about signatures. The proxy is launched per `sc` session
// (see the `sc` shell function), so its cache is scoped to one session and can't
// leak a signature from one conversation into another. Auth is passed through
// untouched: Maki sends the Bearer token it already mints.
//
// Usage: vertex-proxy.js [port]   (port 0 / omitted -> ephemeral; prints chosen port)
// Env:   GOOGLE_VERTEX_LOCATION   (default: global) -> picks the Vertex host.

const http = require('http');
const https = require('https');

// Bump on every behavior change so a running proxy can be checked against the repo.
const VERSION = '1.0.0';

const LOCATION = process.env.GOOGLE_VERTEX_LOCATION || 'global';
const HOST = LOCATION === 'global'
  ? 'aiplatform.googleapis.com'
  : `${LOCATION}-aiplatform.googleapis.com`;

// (function name + canonical args) -> thoughtSignature, populated from responses.
const sigCache = new Map();

function canon(v) {
  if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
  if (v && typeof v === 'object') {
    return '{' + Object.keys(v).sort()
      .map((k) => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
  }
  return JSON.stringify(v);
}

function key(fc) {
  return (fc.name || '') + '|' + canon(fc.args || {});
}

// Yield every part object under contents[]/candidates[] in a parsed body.
function* walkParts(body) {
  if (!body || typeof body !== 'object') return;
  for (const ck of ['contents', 'candidates']) {
    const arr = body[ck];
    if (!Array.isArray(arr)) continue;
    for (const item of arr) {
      const content = item && item.content ? item.content : item;
      if (!content || typeof content !== 'object') continue;
      const parts = content.parts;
      if (!Array.isArray(parts)) continue;
      for (const part of parts) {
        if (part && typeof part === 'object') yield part;
      }
    }
  }
}

// Add cached thoughtSignatures to functionCall parts of a request body.
function inject(raw) {
  let body;
  try { body = JSON.parse(raw.toString('utf8')); } catch { return raw; }
  let changed = false;
  for (const part of walkParts(body)) {
    const fc = part.functionCall;
    if (fc && typeof fc === 'object' && !part.thoughtSignature) {
      const sig = sigCache.get(key(fc));
      if (sig) { part.thoughtSignature = sig; changed = true; }
    }
  }
  return changed ? Buffer.from(JSON.stringify(body), 'utf8') : raw;
}

// Record thoughtSignatures attached to functionCall parts in a response body.
function captureFromJson(text) {
  let obj;
  try { obj = typeof text === 'string' ? JSON.parse(text) : text; } catch { return; }
  for (const part of walkParts(obj)) {
    const fc = part.functionCall;
    const sig = part.thoughtSignature;
    if (fc && typeof fc === 'object' && sig) sigCache.set(key(fc), sig);
  }
}

// Record signatures from streamed `data: {json}` lines.
function captureFromSse(text) {
  for (let line of text.split(/\r?\n/)) {
    line = line.trim();
    if (line.startsWith('data:')) {
      const payload = line.slice(5).trim();
      if (payload && payload !== '[DONE]') captureFromJson(payload);
    }
  }
}

const server = http.createServer((req, res) => {
  // Liveness/version probe — `curl http://127.0.0.1:<port>/__health`.
  if ((req.url || '').split('?')[0] === '/__health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({
      ok: true,
      version: VERSION,
      host: HOST,
      location: LOCATION,
      cachedSignatures: sigCache.size,
    }));
    return;
  }

  // Maki's google base probes `{base}/models` to list models, but Vertex has no
  // such path and returns a 404 HTML page (a noisy "API error 404"). The dynamic
  // provider already supplies the model catalog, so answer the probe ourselves.
  const pathNoQuery = (req.url || '').split('?')[0];
  if (req.method === 'GET' && /\/models$/.test(pathNoQuery)) {
    const models = ['gemini-3.1-flash-lite', 'gemini-3.5-flash', 'gemini-2.5-flash', 'gemini-2.5-pro'].map((id) => ({
      name: 'models/' + id,
      supportedGenerationMethods: ['generateContent', 'streamGenerateContent'],
    }));
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ models }));
    return;
  }

  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    let body = Buffer.concat(chunks);
    if (body.length) body = inject(body);

    const headers = Object.assign({}, req.headers);
    delete headers.host;
    delete headers['content-length'];
    delete headers.connection;
    delete headers['accept-encoding']; // ask Vertex for plain (uncompressed) bodies
    if (body.length) headers['content-length'] = Buffer.byteLength(body);

    const isStream = (req.url || '').includes('streamGenerateContent')
      || (req.url || '').includes('alt=sse');

    const up = https.request(
      { host: HOST, path: req.url, method: req.method, headers },
      (upRes) => {
        const out = Object.assign({}, upRes.headers);
        delete out['content-length'];
        delete out['transfer-encoding'];
        delete out.connection;
        res.writeHead(upRes.statusCode, out); // no content-length -> Node streams chunked

        const collected = [];
        upRes.on('data', (d) => { collected.push(d); res.write(d); });
        upRes.on('end', () => {
          res.end();
          if (upRes.statusCode === 200) {
            const text = Buffer.concat(collected).toString('utf8');
            if (isStream) captureFromSse(text); else captureFromJson(text);
          }
        });
      },
    );
    up.on('error', (e) => {
      if (!res.headersSent) res.writeHead(502);
      res.end('proxy upstream error: ' + e.message);
    });
    if (body.length) up.write(body);
    up.end();
  });
});

// CLI modes for verifying the proxy without launching a server.
const arg = process.argv[2] || '';
if (arg === '--version' || arg === 'version') {
  console.log(VERSION);
  process.exit(0);
}
if (arg === '--selftest') {
  // Prove the capture+inject round-trip with canned data — no network needed.
  const sig = 'TEST_SIGNATURE_ABC';
  captureFromJson(JSON.stringify({
    candidates: [{ content: { parts: [{ functionCall: { name: 'get_weather', args: { city: 'Paris' } }, thoughtSignature: sig }] } }],
  }));
  const out = inject(Buffer.from(JSON.stringify({
    contents: [{ role: 'model', parts: [{ functionCall: { name: 'get_weather', args: { city: 'Paris' } } }] }],
  })));
  const injected = JSON.parse(out.toString('utf8')).contents[0].parts[0].thoughtSignature;
  const pass = injected === sig;
  console.log(`vertex-proxy v${VERSION} selftest: ${pass ? 'PASS' : 'FAIL'} (signature ${pass ? 'captured + re-injected' : 'NOT round-tripped'})`);
  process.exit(pass ? 0 : 1);
}

const port = parseInt(arg || '0', 10);
server.listen(port, '127.0.0.1', () => {
  // Print the actual port once listening; sc reads this and knows we're ready.
  console.log(server.address().port);
});
