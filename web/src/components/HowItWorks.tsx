import { Reveal } from './Reveal'

const STEPS = [
  {
    num: '01',
    title: 'Pair your glasses',
    body: 'Connect your Ray-Ban Meta glasses over the Wearables DAT SDK. No jailbreak, no hardware mods.',
  },
  {
    num: '02',
    title: 'Add your key',
    body: "Paste an OpenAI, Claude, or OpenRouter key into Settings. It's sealed in the Keychain instantly.",
  },
  {
    num: '03',
    title: 'Look and ask',
    body: 'Trigger with Siri or the app, then just talk. Super Meta answers with everything it can see and hear.',
  },
]

export function HowItWorks() {
  return (
    <section id="how" className="container-page mt-32 md:mt-40">
      <Reveal className="mx-auto max-w-2xl text-center">
        <span className="eyebrow">Three steps</span>
        <h2 className="mt-3 text-4xl font-extrabold tracking-tight md:text-5xl">
          From box to brilliant in minutes.
        </h2>
      </Reveal>

      <div className="mt-12 grid gap-4 md:grid-cols-3">
        {STEPS.map((s, i) => (
          <Reveal
            key={s.num}
            delay={i * 0.08}
            className="relative overflow-hidden rounded-card border border-border bg-surface/50 p-7"
          >
            <span className="font-mono text-5xl font-bold text-white/[0.06]">{s.num}</span>
            <h3 className="mt-4 text-xl font-semibold">{s.title}</h3>
            <p className="mt-2 text-sm text-ink-2">{s.body}</p>
          </Reveal>
        ))}
      </div>
    </section>
  )
}
