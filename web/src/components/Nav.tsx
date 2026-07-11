import { useEffect, useState } from 'react'
import { ArrowUpRight } from './Icons'

const LINKS = [
  { href: '#features', label: 'Features' },
  { href: '#providers', label: 'Providers' },
  { href: '#how', label: 'How it works' },
  { href: '#specs', label: 'Specs' },
]

export function Nav() {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-all duration-300 ease-smooth ${
        scrolled ? 'border-b border-border/70 bg-canvas/70 backdrop-blur-xl' : 'border-b border-transparent'
      }`}
    >
      <div className="container-page flex h-16 items-center justify-between">
        <a href="#top" className="flex items-center gap-2.5 font-semibold" aria-label="Super Meta home">
          <img src="/assets/logomark.png" alt="" className="h-7 w-7" />
          <span>Super&nbsp;Meta</span>
        </a>

        <nav className="hidden items-center gap-8 text-sm text-ink-2 md:flex" aria-label="Primary">
          {LINKS.map((l) => (
            <a key={l.href} href={l.href} className="transition-colors hover:text-ink">
              {l.label}
            </a>
          ))}
        </nav>

        <a href="#download" className="btn-primary px-5 py-2 text-sm">
          Get the app
          <ArrowUpRight />
        </a>
      </div>
    </header>
  )
}
