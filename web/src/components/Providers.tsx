import { Reveal } from './Reveal'

const ROWS = [
  { name: 'OpenAI', tag: 'Realtime · Vision' },
  { name: 'Anthropic Claude', tag: 'Vision · Chat' },
  { name: 'OpenRouter', tag: 'Any model' },
]

const CHECKS = [
  'Vision runs on your selected provider',
  'Realtime voice on OpenAI Realtime GA',
  'Keys stored in the Keychain, on-device',
  'No account, no telemetry, no middleman',
]

export function Providers() {
  return (
    <section id="providers" className="container-page mt-32 md:mt-40">
      <div className="grid items-center gap-12 lg:grid-cols-2">
        <Reveal>
          <span className="eyebrow">Your keys, your rules</span>
          <h2 className="mt-3 text-4xl font-extrabold tracking-tight md:text-5xl">
            Bring the model you
            <br />
            already trust.
          </h2>
          <p className="mt-5 max-w-md text-ink-2">
            Super Meta doesn&apos;t lock you into a black box. Drop in your own key for OpenAI, Anthropic
            Claude, or OpenRouter and pick the model per feature. Keys live in the iOS Keychain — never on
            our servers, because there are none.
          </p>
          <ul className="mt-6 space-y-3">
            {CHECKS.map((c) => (
              <li key={c} className="flex items-start gap-3 text-ink">
                <svg viewBox="0 0 20 20" className="mt-0.5 h-5 w-5 shrink-0 text-positive" fill="none">
                  <circle cx="10" cy="10" r="9" stroke="currentColor" strokeWidth="1.4" opacity="0.4" />
                  <path d="M6 10.5l2.5 2.5L14 7.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                <span className="text-sm">{c}</span>
              </li>
            ))}
          </ul>
        </Reveal>

        <Reveal delay={0.1}>
          <div className="glass rounded-card p-2">
            {ROWS.map((r) => (
              <div
                key={r.name}
                className="flex items-center justify-between rounded-2xl px-4 py-4 transition-colors hover:bg-white/[0.03]"
              >
                <span className="font-semibold">{r.name}</span>
                <span className="font-mono text-xs text-ink-2">{r.tag}</span>
                <span className="h-2 w-2 rounded-full bg-positive animate-pulseDot" />
              </div>
            ))}
            <div className="mt-1 border-t border-border px-4 py-3">
              <span className="font-mono text-xs text-ink-3">keychain · aes-256 · on-device</span>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  )
}
