import { FEATURES } from '../data'
import { Icon } from './Icons'
import { Reveal } from './Reveal'

export function Features() {
  return (
    <section id="features" className="container-page mt-32 md:mt-40">
      <Reveal className="mx-auto max-w-2xl text-center">
        <span className="eyebrow">Everything on your face</span>
        <h2 className="mt-3 text-4xl font-extrabold tracking-tight md:text-5xl">One assistant. Every sense.</h2>
        <p className="mt-4 text-ink-2">
          Eight capabilities, one editorial home screen. Point, ask, and go — no phone in your hand.
        </p>
      </Reveal>

      <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {FEATURES.map((f, i) => (
          <Reveal
            as="article"
            key={f.title}
            delay={(i % 4) * 0.06}
            className="group relative overflow-hidden rounded-card border border-border bg-surface/60 p-6 transition-all duration-300 ease-smooth hover:-translate-y-1 hover:border-white/15"
          >
            {/* tint glow */}
            <div
              className="pointer-events-none absolute -right-10 -top-10 h-28 w-28 rounded-full opacity-0 blur-2xl transition-opacity duration-500 group-hover:opacity-40"
              style={{ background: f.tint }}
            />
            <div
              className="mb-4 inline-flex h-11 w-11 items-center justify-center rounded-xl border border-white/10"
              style={{ color: f.tint, background: `${f.tint}14` }}
            >
              <Icon name={f.icon} className="h-5 w-5" />
            </div>
            <h3 className="text-lg font-semibold">{f.title}</h3>
            <p className="mt-2 text-sm text-ink-2">{f.body}</p>
          </Reveal>
        ))}
      </div>
    </section>
  )
}
