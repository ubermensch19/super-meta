import type { IconName } from '../data'

const paths: Record<IconName, JSX.Element> = {
  voice: (
    <>
      <path d="M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3Z" />
      <path d="M5 11a7 7 0 0 0 14 0M12 18v3" strokeLinecap="round" />
    </>
  ),
  globe: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3c2.5 2.5 2.5 15 0 18M12 3c-2.5 2.5-2.5 15 0 18" />
    </>
  ),
  eye: (
    <>
      <path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6Z" />
      <circle cx="12" cy="12" r="2.6" />
    </>
  ),
  chat: (
    <>
      <path d="M4 5h13l3 3v11a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z" />
      <path d="M8 10h6M8 14h4" strokeLinecap="round" />
    </>
  ),
  leaf: (
    <>
      <path d="M12 3c3 3.5 3 8 0 11-3-3-3-7.5 0-11Z" />
      <path d="M12 14v7M8 21h8" strokeLinecap="round" />
    </>
  ),
  node: (
    <>
      <path d="M12 12v9M8 21h8" strokeLinecap="round" />
      <path d="M6 9a6 6 0 0 1 12 0M9 9a3 3 0 0 1 6 0" />
    </>
  ),
  stream: (
    <>
      <circle cx="12" cy="12" r="2.4" />
      <path
        d="M6.5 6.5a7.8 7.8 0 0 0 0 11M17.5 6.5a7.8 7.8 0 0 1 0 11M3.5 3.5a12 12 0 0 0 0 17M20.5 3.5a12 12 0 0 1 0 17"
        strokeLinecap="round"
      />
    </>
  ),
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" strokeLinecap="round" />
    </>
  ),
}

export function Icon({ name, className }: { name: IconName; className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.6}
      className={className}
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  )
}

export function ArrowUpRight({ className }: { className?: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" className={className} aria-hidden="true">
      <path
        d="M4 12L12 4M12 4H6M12 4V10"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}
