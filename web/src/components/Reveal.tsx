import { motion, useReducedMotion } from 'framer-motion'
import type { ReactNode } from 'react'

/** Reveal-on-scroll wrapper with a soft rise + fade, honoring reduced motion. */
export function Reveal({
  children,
  delay = 0,
  as = 'div',
  className,
}: {
  children: ReactNode
  delay?: number
  as?: 'div' | 'li' | 'article' | 'section'
  className?: string
}) {
  const reduce = useReducedMotion()
  const MotionTag = motion[as]

  return (
    <MotionTag
      className={className}
      initial={reduce ? undefined : { opacity: 0, y: 26 }}
      whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '0px 0px -8% 0px' }}
      transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1], delay }}
    >
      {children}
    </MotionTag>
  )
}
