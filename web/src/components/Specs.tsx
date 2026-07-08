import { useEffect, useRef, useState } from 'react'
import { useInView, useReducedMotion } from 'framer-motion'
import { Reveal } from './Reveal'

const STATS = [
  { to: 11, suffix: '', unit: 'languages, live' },
  { to: 7, suffix: '', unit: 'vision modes' },
  { to: 240, suffix: 'ms', unit: 'voice round-trip' },
  { to: 100, suffix: '%', unit: 'on-device keys' },
]

function Counter({ to, suffix }: { to: number; suffix: string }) {
  const reduce = useReducedMotion()
  const ref = useRef<HTMLSpanElement>(null)
  const inView = useInView(ref, { once: true, amount: 0.6 })
  const [val, setVal] = useState(reduce ? to : 0)

  useEffect(() => {
    if (!inView || reduce) {
      if (reduce) setVal(to)
      return
    }
    const dur = 1200
    let start: number | undefined
    let raf = 0
    const tick = (t: number) => {
      if (start === undefined) start = t
      const p = Math.min((t - start) / dur, 1)
      const eased = 1 - Math.pow(1 - p, 3)
      setVal(Math.round(to * eased))
      if (p < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [inView, reduce, to])

  return (
    <span ref={ref} className="tabular-nums">
      {val}
      {suffix}
    </span>
  )
}

export function Specs() {
  return (
    <section id="specs" className="container-page mt-32 md:mt-40">
      <Reveal className="glass overflow-hidden rounded-card p-8 md:p-12">
        <div className="text-center">
          <span className="eyebrow">Under the hood</span>
          <h2 className="mt-3 text-3xl font-extrabold tracking-tight md:text-4xl">Native. Fast. Private.</h2>
        </div>

        <div className="mt-10 grid grid-cols-2 gap-8 md:grid-cols-4">
          {STATS.map((s) => (
            <div key={s.unit} className="text-center">
              <div className="text-4xl font-extrabold text-accent md:text-5xl">
                <Counter to={s.to} suffix={s.suffix} />
              </div>
              <div className="mt-2 text-sm text-ink-2">{s.unit}</div>
            </div>
          ))}
        </div>

        <div className="mt-10 border-t border-border pt-6 text-center font-mono text-xs text-ink-3">
          Swift 6 · iOS 17+ · SwiftData history · Siri App Intents · RTMP broadcast · DAT SDK v20+
        </div>
      </Reveal>
    </section>
  )
}
