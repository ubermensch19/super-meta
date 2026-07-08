import { useRef, useState } from 'react'
import { motion, useScroll, useTransform, useSpring, useReducedMotion, useMotionValueEvent } from 'framer-motion'
import { SCENES } from '../data'
import { HudDevice } from './HudDevice'

/**
 * Scroll-driven sticky showcase. As the user scrolls the tall track, the pinned
 * device cycles through vision scenes and a progress rail advances.
 */
export function VisionShowcase() {
  const reduce = useReducedMotion()
  const ref = useRef<HTMLDivElement>(null)
  const [active, setActive] = useState(0)

  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end end'] })
  const progress = useSpring(scrollYProgress, { stiffness: 90, damping: 20 })
  const railScale = useTransform(progress, [0, 1], [0, 1])

  useMotionValueEvent(scrollYProgress, 'change', (v) => {
    const idx = Math.min(SCENES.length - 1, Math.floor(v * SCENES.length))
    setActive(idx)
  })

  return (
    <section id="showcase" ref={ref} className="relative mt-32 h-[340vh] md:mt-40">
      <div className="sticky top-0 flex min-h-screen items-center overflow-hidden">
        <div className="container-page grid items-center gap-12 lg:grid-cols-2">
          {/* Left: narrative */}
          <div>
            <span className="eyebrow">See it think</span>
            <h2 className="mt-3 text-4xl font-extrabold tracking-tight md:text-5xl">
              One glance.
              <br />
              <span className="grad-text animate-shimmer">A real answer.</span>
            </h2>
            <p className="mt-5 max-w-md text-ink-2">
              Scroll to watch a single frame become recognition, translation, nutrition, and agent action —
              all on-device, all in the moment.
            </p>

            {/* progress rail */}
            <div className="relative mt-8 h-px w-40 overflow-hidden rounded bg-border">
              <motion.div
                className="absolute inset-y-0 left-0 w-full origin-left rounded bg-accent"
                style={{ scaleX: reduce ? 1 : railScale }}
              />
            </div>

            {/* scene list */}
            <ul className="mt-8 space-y-3">
              {SCENES.map((s, i) => (
                <li
                  key={s.tag}
                  className={`flex items-center gap-3 font-mono text-sm transition-colors duration-300 ${
                    i === active ? 'text-ink' : 'text-ink-3'
                  }`}
                >
                  <span
                    className="h-1.5 w-1.5 rounded-full transition-all duration-300"
                    style={{
                      background: i === active ? s.tint : '#2E2F3A',
                      boxShadow: i === active ? `0 0 12px ${s.tint}` : 'none',
                    }}
                  />
                  {s.tag}
                </li>
              ))}
            </ul>
          </div>

          {/* Right: pinned device */}
          <div className="flex justify-center [perspective:1200px]">
            <motion.div
              key={active}
              initial={reduce ? undefined : { opacity: 0, y: 16, rotateY: -6 }}
              animate={reduce ? undefined : { opacity: 1, y: 0, rotateY: 0 }}
              transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
              style={{ transformStyle: 'preserve-3d' }}
            >
              <HudDevice scene={SCENES[active]} active />
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  )
}
