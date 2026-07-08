import { useEffect, useRef, useState } from 'react'
import { useReducedMotion } from 'framer-motion'
import type { ShowcaseScene } from '../data'

/** Live-drifting fps / latency readout. */
function useReadout(reduce: boolean | null) {
  const [text, setText] = useState('◎ 60 fps · 240 ms')
  useEffect(() => {
    if (reduce) return
    const id = setInterval(() => {
      const fps = 58 + Math.floor(Math.random() * 5)
      const ms = 210 + Math.floor(Math.random() * 60)
      setText(`◎ ${fps} fps · ${ms} ms`)
    }, 900)
    return () => clearInterval(id)
  }, [reduce])
  return text
}

/** Typewriter that re-types whenever `full` changes. */
function useTypewriter(full: string, reduce: boolean | null, active: boolean) {
  const [out, setOut] = useState(reduce ? full : '')
  const timer = useRef<number>()
  useEffect(() => {
    if (reduce || !active) {
      setOut(full)
      return
    }
    setOut('')
    let i = 0
    const tick = () => {
      i += 1
      setOut(full.slice(0, i))
      if (i < full.length) timer.current = window.setTimeout(tick, 34 + Math.random() * 34)
    }
    timer.current = window.setTimeout(tick, 260)
    return () => window.clearTimeout(timer.current)
  }, [full, reduce, active])
  return out
}

export function HudDevice({ scene, active = true }: { scene: ShowcaseScene; active?: boolean }) {
  const reduce = useReducedMotion()
  const readout = useReadout(reduce)
  const heard = useTypewriter(scene.heard, reduce, active)

  return (
    <div className="glass w-full max-w-[420px] rounded-card p-4 shadow-[0_30px_80px_-24px_rgba(0,0,0,0.8)]">
      {/* top bar */}
      <div className="flex items-center justify-between font-mono text-[11px]">
        <span className="inline-flex items-center gap-1.5 text-live">
          <span className="h-1.5 w-1.5 rounded-full bg-live animate-pulseDot" />
          LIVE&nbsp;AI
        </span>
        <span className="text-ink-2">{readout}</span>
      </div>

      {/* scene viewport */}
      <div className="relative mt-3 h-44 overflow-hidden rounded-2xl border border-white/5 bg-gradient-to-br from-white/[0.04] to-transparent">
        <div
          className="absolute inset-0 opacity-30 blur-2xl"
          style={{ background: `radial-gradient(60% 60% at 50% 40%, ${scene.tint}, transparent)` }}
        />
        <img
          src="/assets/logomark.png"
          alt=""
          className="absolute left-1/2 top-1/2 h-16 w-16 -translate-x-1/2 -translate-y-1/2 opacity-90"
        />
        <div className="absolute left-3 top-3 font-mono text-[10px] tracking-[0.2em] text-ink-2">
          {scene.tag}
        </div>
        {/* corner brackets */}
        <span className="absolute left-3 top-3 h-4 w-4 border-l border-t border-white/25" />
        <span className="absolute right-3 top-3 h-4 w-4 border-r border-t border-white/25" />
        <span className="absolute bottom-3 left-3 h-4 w-4 border-b border-l border-white/25" />
        <span className="absolute bottom-3 right-3 h-4 w-4 border-b border-r border-white/25" />
        {/* scan line */}
        <div
          className="absolute inset-x-0 top-0 h-16 animate-scan"
          style={{
            background: `linear-gradient(to bottom, transparent, ${scene.tint}22, transparent)`,
          }}
        />
      </div>

      {/* heard */}
      <div className="mt-4">
        <span className="font-mono text-[10px] tracking-[0.2em] text-ink-2">HEARD</span>
        <p className="mt-1 min-h-[2.4em] text-sm text-ink">
          {heard}
          {!reduce && active && heard.length < scene.heard.length && (
            <span className="ml-0.5 inline-block h-4 w-[2px] translate-y-0.5 bg-accent align-middle animate-pulseDot" />
          )}
        </p>
      </div>

      {/* answered */}
      <div className="mt-3 rounded-xl border border-white/5 bg-white/[0.02] p-3">
        <span className="font-mono text-[10px] tracking-[0.2em]" style={{ color: scene.tint }}>
          ANSWERED · {scene.latency}
        </span>
        <p className="mt-1 text-sm text-ink">{scene.answered}</p>
      </div>
    </div>
  )
}
