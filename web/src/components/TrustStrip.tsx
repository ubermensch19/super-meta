const ITEMS = ['OpenAI', 'Anthropic Claude', 'OpenRouter', 'OpenClaw', 'Hermes']

export function TrustStrip() {
  const row = [...ITEMS, ...ITEMS]
  return (
    <section className="container-page mt-24 md:mt-28" aria-label="Bring your own model">
      <div className="flex flex-col items-center gap-6 md:flex-row md:gap-10">
        <span className="shrink-0 font-mono text-xs uppercase tracking-[0.24em] text-ink-3">
          Bring your own model
        </span>
        <div className="relative w-full overflow-hidden [mask-image:linear-gradient(90deg,transparent,#000_12%,#000_88%,transparent)]">
          <div className="flex w-max animate-marquee gap-10">
            {row.map((item, i) => (
              <span key={i} className="whitespace-nowrap text-lg font-medium text-ink-2">
                {item}
                <span className="ml-10 text-ink-3">·</span>
              </span>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
