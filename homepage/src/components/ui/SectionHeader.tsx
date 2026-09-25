import type { ReactNode } from "react";

interface SectionHeaderProps {
  index: string;
  eyebrow: string;
  title: ReactNode;
  lede?: ReactNode;
  align?: "left" | "center";
  className?: string;
}

/** Shared section opener: "01 — Eyebrow", a sentence-case title, a short lede. */
export default function SectionHeader({
  index,
  eyebrow,
  title,
  lede,
  align = "left",
  className = "",
}: SectionHeaderProps) {
  const centered = align === "center";
  return (
    <div
      className={`reveal flex max-w-2xl flex-col gap-4 ${
        centered ? "mx-auto items-center text-center" : ""
      } ${className}`}
    >
      <p className="eyebrow">
        <span className="eyebrow-index">{index}</span>
        <span className="eyebrow-rule" aria-hidden="true" />
        <span>{eyebrow}</span>
      </p>
      <h2 className="text-[32px] font-black leading-[1.05] tracking-[-0.03em] text-foreground md:text-5xl">
        {title}
      </h2>
      {lede && (
        <p className="text-base leading-relaxed text-muted-foreground md:text-lg">{lede}</p>
      )}
    </div>
  );
}
