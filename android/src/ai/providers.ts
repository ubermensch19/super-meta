// Portable AI provider layer — mirrors Packages/AIProviders from the native app.
// All three providers speak the OpenAI chat-completions shape, so one client covers them.
// This is the part of the app that ports 1:1 to React Native (pure fetch, no native code).

export type ProviderId = 'openai' | 'anthropic' | 'openrouter';

export interface Provider {
  id: ProviderId;
  label: string;
  endpoint: string;
  /** Extra headers (e.g. OpenRouter attribution). API key is added at call time. */
  headers?: Record<string, string>;
  /** Header name the key goes in, and how it's formatted. */
  authHeader: (key: string) => Record<string, string>;
  models: string[];
}

export const PROVIDERS: Record<ProviderId, Provider> = {
  openai: {
    id: 'openai',
    label: 'OpenAI',
    endpoint: 'https://api.openai.com/v1/chat/completions',
    authHeader: (k) => ({ Authorization: `Bearer ${k}` }),
    models: ['gpt-4o', 'gpt-4o-mini', 'o4-mini'],
  },
  anthropic: {
    id: 'anthropic',
    label: 'Anthropic',
    endpoint: 'https://api.anthropic.com/v1/messages',
    headers: { 'anthropic-version': '2023-06-01' },
    authHeader: (k) => ({ 'x-api-key': k }),
    models: ['claude-opus-4-8', 'claude-sonnet-5', 'claude-haiku-4-5-20251001'],
  },
  openrouter: {
    id: 'openrouter',
    label: 'OpenRouter',
    endpoint: 'https://openrouter.ai/api/v1/chat/completions',
    headers: {
      'HTTP-Referer': 'https://github.com/priyanshu/super-meta',
      'X-Title': 'Super Meta',
    },
    authHeader: (k) => ({ Authorization: `Bearer ${k}` }),
    models: ['anthropic/claude-opus-4.8', 'openai/gpt-4o', 'google/gemini-2.5-pro'],
  },
};

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/**
 * Send a chat request. Anthropic uses a slightly different envelope than the
 * OpenAI-compatible providers, handled here so callers stay provider-agnostic.
 */
export async function chat(
  providerId: ProviderId,
  apiKey: string,
  model: string,
  messages: ChatMessage[],
): Promise<string> {
  const p = PROVIDERS[providerId];
  const headers = {
    'Content-Type': 'application/json',
    ...(p.headers ?? {}),
    ...p.authHeader(apiKey),
  };

  if (providerId === 'anthropic') {
    const system = messages.find((m) => m.role === 'system')?.content;
    const rest = messages.filter((m) => m.role !== 'system');
    const res = await fetch(p.endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify({ model, max_tokens: 1024, system, messages: rest }),
    });
    if (!res.ok) throw new Error(`${p.label} ${res.status}: ${await res.text()}`);
    const json = await res.json();
    return json.content?.[0]?.text ?? '';
  }

  const res = await fetch(p.endpoint, {
    method: 'POST',
    headers,
    body: JSON.stringify({ model, messages }),
  });
  if (!res.ok) throw new Error(`${p.label} ${res.status}: ${await res.text()}`);
  const json = await res.json();
  return json.choices?.[0]?.message?.content ?? '';
}
