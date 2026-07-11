export function Footer() {
  return (
    <footer className="container-page mt-28 border-t border-border py-12">
      <div className="flex flex-col items-start justify-between gap-6 md:flex-row md:items-center">
        <div className="flex items-center gap-2.5 font-semibold">
          <img src="/assets/logomark.png" alt="" className="h-6 w-6" />
          <span>Super Meta</span>
        </div>
        <div className="flex gap-6 text-sm text-ink-2">
          <a href="#features" className="transition-colors hover:text-ink">
            Features
          </a>
          <a href="#providers" className="transition-colors hover:text-ink">
            Providers
          </a>
          <a href="#download" className="transition-colors hover:text-ink">
            Access
          </a>
        </div>
      </div>
      <p className="mt-8 max-w-2xl text-xs leading-relaxed text-ink-3">
        A working name for development only. &ldquo;Meta&rdquo; is a trademark of Meta Platforms and Super
        Meta is not affiliated with, endorsed by, or sponsored by Meta.
      </p>
    </footer>
  )
}
