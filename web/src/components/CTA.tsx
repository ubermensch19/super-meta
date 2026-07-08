import { useState } from 'react'
import type { FormEvent } from 'react'
import { Reveal } from './Reveal'

export function CTA() {
  const [done, setDone] = useState(false)

  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const input = e.currentTarget.elements.namedItem('email') as HTMLInputElement | null
    if (!input || !input.value || !input.checkValidity()) {
      input?.focus()
      return
    }
    setDone(true)
  }

  return (
    <section id="download" className="container-page mt-32 md:mt-40">
      <Reveal className="relative overflow-hidden rounded-card border border-border bg-surface/50 px-6 py-16 text-center md:py-24">
        {/* glow */}
        <div className="pointer-events-none absolute left-1/2 top-0 h-72 w-72 -translate-x-1/2 -translate-y-1/3 rounded-full bg-accent/25 blur-[100px]" />
        <img src="/assets/logomark.png" alt="" className="mx-auto h-14 w-14" />
        <h2 className="mx-auto mt-6 max-w-2xl text-4xl font-extrabold tracking-tight md:text-6xl">
          Put an AI <span className="grad-text animate-shimmer">behind your eyes.</span>
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-ink-2">
          Super Meta is in active development for Ray-Ban Meta glasses. Get early access and be first when it
          ships.
        </p>

        {done ? (
          <p className="mx-auto mt-8 inline-flex items-center gap-2 rounded-full border border-positive/40 bg-positive/10 px-5 py-3 text-positive">
            You&apos;re on the list ✓
          </p>
        ) : (
          <form onSubmit={onSubmit} className="mx-auto mt-8 flex max-w-md flex-col gap-3 sm:flex-row">
            <input
              name="email"
              type="email"
              required
              placeholder="you@email.com"
              aria-label="Email address"
              className="w-full flex-1 rounded-full border border-border bg-canvas/60 px-5 py-3 text-ink outline-none transition-colors placeholder:text-ink-3 focus:border-accent"
            />
            <button type="submit" className="btn-primary shrink-0">
              Request access
            </button>
          </form>
        )}

        <p className="mt-6 font-mono text-xs text-ink-3">
          iOS 17+ · Ray-Ban Meta glasses · Xcode 16 to build from source.
        </p>
      </Reveal>
    </section>
  )
}
