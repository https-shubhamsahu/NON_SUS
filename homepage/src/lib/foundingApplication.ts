// Founding-team interest form — client-side only.
// There is no applications table or edge function. Submit builds a mailto
// draft to the developer address; the message is sent only if the person
// actually sends the email from their own mail client.

export const FOUNDING_ROLES = [
  {
    id: "engineering",
    label: "Engineering",
    hint: "Flutter, web, Postgres, or crypto",
  },
  {
    id: "design",
    label: "Design",
    hint: "Product, brand, or the paper-ink UI",
  },
  {
    id: "growth",
    label: "Growth",
    hint: "Distribution without ad trackers",
  },
  {
    id: "operations",
    label: "Operations",
    hint: "Support, docs, or running the service",
  },
  {
    id: "other",
    label: "Other",
    hint: "Say what in the note below",
  },
] as const;

export type FoundingRoleId = (typeof FOUNDING_ROLES)[number]["id"];

export const FOUNDING_HOURS = [
  { id: "", label: "Prefer not to say" },
  { id: "evenings", label: "Evenings / weekends" },
  { id: "part-time", label: "Part-time" },
  { id: "full-time", label: "Full-time interest" },
  { id: "unsure", label: "Not sure yet" },
] as const;

export type FoundingHoursId = (typeof FOUNDING_HOURS)[number]["id"];

export const FOUNDING_LIMITS = {
  name: 80,
  email: 120,
  links: 400,
  why: 800,
  location: 80,
  heard: 160,
} as const;

/** Practical ceiling for the whole mailto URL (some clients truncate ~2k). */
export const MAILTO_MAX_CHARS = 1800;

export const FOUNDING_SUBJECT_PREFIX = "NO SUS founding team";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export type FoundingApplication = {
  name: string;
  email: string;
  roles: FoundingRoleId[];
  links: string;
  why: string;
  location: string;
  hours: FoundingHoursId;
  heard: string;
};

export type FoundingFieldErrors = Partial<
  Record<"name" | "email" | "roles" | "links" | "why" | "location" | "heard", string>
>;

export function emptyFoundingApplication(): FoundingApplication {
  return {
    name: "",
    email: "",
    roles: [],
    links: "",
    why: "",
    location: "",
    hours: "",
    heard: "",
  };
}

export function clip(value: string, max: number): string {
  return value.replace(/\r\n/g, "\n").slice(0, max);
}

export function roleLabel(id: FoundingRoleId): string {
  return FOUNDING_ROLES.find((role) => role.id === id)?.label ?? id;
}

export function hoursLabel(id: FoundingHoursId): string {
  return FOUNDING_HOURS.find((row) => row.id === id)?.label ?? id;
}

export function validateFoundingApplication(
  raw: FoundingApplication,
): { ok: true; value: FoundingApplication } | { ok: false; errors: FoundingFieldErrors } {
  const errors: FoundingFieldErrors = {};
  const name = clip(raw.name.trim(), FOUNDING_LIMITS.name);
  const email = clip(raw.email.trim(), FOUNDING_LIMITS.email);
  const links = clip(raw.links.trim(), FOUNDING_LIMITS.links);
  const why = clip(raw.why.trim(), FOUNDING_LIMITS.why);
  const location = clip(raw.location.trim(), FOUNDING_LIMITS.location);
  const heard = clip(raw.heard.trim(), FOUNDING_LIMITS.heard);
  const hours = FOUNDING_HOURS.some((row) => row.id === raw.hours)
    ? raw.hours
    : ("" as FoundingHoursId);
  const roles = FOUNDING_ROLES.map((role) => role.id).filter((id) =>
    raw.roles.includes(id),
  );

  if (name.length < 2) errors.name = "Name is required.";
  if (!EMAIL_RE.test(email)) errors.email = "A real email address is required.";
  if (roles.length === 0) errors.roles = "Pick at least one area.";
  if (why.length < 20) {
    errors.why = "Tell us in a couple of sentences what you would bring (at least 20 characters).";
  }

  if (Object.keys(errors).length > 0) return { ok: false, errors };

  return {
    ok: true,
    value: { name, email, roles, links, why, location, hours, heard },
  };
}

export function formatFoundingEmailBody(app: FoundingApplication): string {
  const lines = [
    "NO SUS founding-team interest",
    "",
    `Name: ${app.name}`,
    `Email: ${app.email}`,
    `Roles: ${app.roles.map(roleLabel).join(", ")}`,
  ];
  if (app.links) lines.push(`Links: ${app.links}`);
  if (app.location) lines.push(`Location / timezone: ${app.location}`);
  if (app.hours) lines.push(`Hours: ${hoursLabel(app.hours)}`);
  if (app.heard) lines.push(`How they heard: ${app.heard}`);
  lines.push("", "What they'd bring:", app.why);
  return lines.join("\n");
}

export type FoundingMailto = {
  to: string;
  subject: string;
  body: string;
  href: string;
  truncated: boolean;
};

export function buildFoundingMailto(
  to: string,
  app: FoundingApplication,
): FoundingMailto {
  const subject = `${FOUNDING_SUBJECT_PREFIX} — ${app.name}`;
  let body = formatFoundingEmailBody(app);
  let href = `mailto:${to}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  let truncated = false;

  // If the encoded URL is too long, shrink the note rather than drop the draft.
  if (href.length > MAILTO_MAX_CHARS) {
    truncated = true;
    const overhead = href.length - encodeURIComponent(body).length;
    const budget = Math.max(120, MAILTO_MAX_CHARS - overhead - 24);
    let cut = body;
    while (encodeURIComponent(cut).length > budget && cut.length > 40) {
      cut = `${cut.slice(0, Math.max(40, cut.length - 40)).trimEnd()}\n…`;
    }
    body = cut;
    href = `mailto:${to}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  }

  return { to, subject, body, href, truncated };
}
