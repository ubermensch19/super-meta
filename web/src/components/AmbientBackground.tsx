import { motion, useReducedMotion } from 'framer-motion'

/** Drifting color orbs + grid + film noise. The cinematic HUD backdrop. */
export function AmbientBackground() {
  const reduce = useReducedMotion()

  const orb = (extra: object) =>
    reduce
      ? {}
      : {
          animate: { x: [0, '6vw', 0], y: [0, '5vw', 0], scale: [1, 1.12, 1] },
          transition: { duration: 24, repeat: Infinity, ease: 'easeInOut', ...extra },
        }

  return (
    <div className="pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-canvas" aria-hidden="true">
      <motion.div
        className="absolute -left-[8vw] -top-[12vw] h-[46vw] w-[46vw] rounded-full bg-accent opacity-40 blur-[90px]"
        {...orb({})}
      />
      <motion.div
        className="absolute -right-[14vw] top-[20vw] h-[42vw] w-[42vw] rounded-full bg-live opacity-30 blur-[90px]"
        {...orb({ duration: 30 })}
      />
      <motion.div
        className="absolute -bottom-[14vw] left-[24vw] h-[38vw] w-[38vw] rounded-full bg-positive opacity-20 blur-[90px]"
        {...orb({ duration: 27 })}
      />
      <div className="absolute inset-0 grid-mask" />
      <div className="noise-layer absolute inset-0 opacity-50" />
      <div className="absolute inset-x-0 bottom-0 h-[30vh] bg-gradient-to-t from-canvas to-transparent" />
    </div>
  )
}
