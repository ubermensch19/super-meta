import type { PointerEvent } from 'react'
import { motion, useMotionValue, useSpring, useTransform, useReducedMotion } from 'framer-motion'
import { SCENES } from '../data'
import { HudDevice } from './HudDevice'
import { ArrowUpRight } from './Icons'

const CHIPS = [
  { label: 'Glasses connected', color: '#39E0A0', pos: 'left-2 top-6 md:-left-8' },
  { label: 'Vision · Quick', color: '#FFA62B', pos: 'right-2 top-1/3 md:-right-10' },
  { label: 'Streaming RTMP', color: '#FF4D8D', pos: 'left-6 bottom-4 md:-left-6' },
]

export function Hero() {
  const reduce = useReducedMotion()

  // Mouse-parallax 3D tilt for the device.
  const px = useMotionValue(0)
  const py = useMotionValue(0)
  const rotateY = useSpring(useTransform(px, [-0.5, 0.5], [12, -12]), { stiffness: 120, damping: 14 })
  const rotateX = useSpring(useTransform(py, [-0.5, 0.5], [-10, 10]), { stiffness: 120, damping: 14 })

  const onMove = (e: PointerEvent<HTMLDivElement>) => {
    if (reduce) return
    const r = e.currentTarget.getBoundingClientRect()
    px.set((e.clientX - r.left) / r.width - 0.5)
    py.set((e.clientY - r.top) / r.height - 0.5)
  }
  const onLeave = () => {
    px.set(0)
    py.set(0)
  }

  return (
    <section className="relative pt-28 md:pt-36" id="top">
      <div className="container-page grid items-center gap-14 lg:grid-cols-[1.05fr_0.95fr]">
        {/* Copy */}
        <div>
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
            className="inline-flex items-center gap-2 rounded-full border border-border bg-white/[0.03] px-3.5 py-1.5 text-xs text-ink-2"
          >
            <span className="h-1.5 w-1.5 rounded-full bg-accent animate-pulseDot" />
            Built on Meta&apos;s Wearables DAT SDK
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.06, ease: [0.22, 1, 0.36, 1] }}
            className="mt-5 text-5xl font-extrabold leading-[1.03] tracking-tight md:text-7xl"
          >
            Your glasses,
            <br />
            <span className="grad-text animate-shimmer">now they think.</span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.12, ease: [0.22, 1, 0.36, 1] }}
            className="mt-6 max-w-xl text-lg text-ink-2"
          >
            Super Meta turns your Ray-Ban&nbsp;Meta glasses into a real-time AI assistant. It sees what you
            see and hears what you hear — answering, translating, and recognizing the world in the moment.
            Your provider, your keys, on your face.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.18, ease: [0.22, 1, 0.36, 1] }}
            className="mt-8 flex flex-wrap items-center gap-3"
          >
            <a href="#download" className="btn-primary">
              Get Super Meta
              <ArrowUpRight />
            </a>
            <a href="#how" className="btn-ghost">
              See how it works
            </a>
          </motion.div>

          <motion.ul
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.7, delay: 0.28 }}
            className="mt-10 flex flex-wrap gap-x-8 gap-y-3 font-mono text-sm text-ink-2"
          >
            <li>
              <b className="text-ink">11</b> languages, live
            </li>
            <li>
              <b className="text-ink">3</b> AI providers
            </li>
            <li>
              <b className="text-ink">7</b> vision modes
            </li>
          </motion.ul>
        </div>

        {/* Device stage */}
        <motion.div
          initial={{ opacity: 0, scale: 0.94 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.8, delay: 0.15, ease: [0.22, 1, 0.36, 1] }}
          className="relative flex justify-center [perspective:1200px]"
          onPointerMove={onMove}
          onPointerLeave={onLeave}
        >
          <motion.div style={{ rotateX, rotateY, transformStyle: 'preserve-3d' }} className="relative">
            <HudDevice scene={SCENES[0]} />
            {CHIPS.map((c) => (
              <motion.div
                key={c.label}
                className={`absolute ${c.pos} glass flex items-center gap-2 rounded-full px-3 py-1.5 text-xs text-ink`}
                style={{ transform: 'translateZ(60px)' }}
                animate={reduce ? undefined : { y: [0, -7, 0] }}
                transition={{ duration: 4 + Math.random() * 2, repeat: Infinity, ease: 'easeInOut' }}
              >
                <span className="h-1.5 w-1.5 rounded-full" style={{ background: c.color }} />
                {c.label}
              </motion.div>
            ))}
          </motion.div>
        </motion.div>
      </div>
    </section>
  )
}
