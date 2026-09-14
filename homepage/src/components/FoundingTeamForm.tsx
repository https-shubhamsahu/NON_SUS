"use client";

import { FormEvent, useId, useState } from "react";
import { Check, Copy, Mail } from "lucide-react";
import { DEVELOPER, PRIVACY_URL } from "@/lib/links";
import {
  FOUNDING_HOURS,
  FOUNDING_LIMITS,
  FOUNDING_ROLES,
  FoundingApplication,
  FoundingFieldErrors,
  FoundingMailto,
  FoundingRoleId,
  buildFoundingMailto,
  clip,
  emptyFoundingApplication,
  validateFoundingApplication,
} from "@/lib/foundingApplication";

const inputClass =
  "mt-1.5 w-full bg-brand-black border border-brand-gray px-3 py-2.5 text-sm text-white placeholder:text-brand-gray-light/60 focus:border-white focus:outline-none";

export default function FoundingTeamForm() {
  const formId = useId();
  const [app, setApp] = useState<FoundingApplication>(emptyFoundingApplication);
  const [errors, setErrors] = useState<FoundingFieldErrors>({});
  const [draft, setDraft] = useState<FoundingMailto | null>(null);
  const [copied, setCopied] = useState(false);
  const [copyError, setCopyError] = useState("");

  const setField = <K extends keyof FoundingApplication>(
    key: K,
    value: FoundingApplication[K],
  ) => {
    setApp((prev) => ({ ...prev, [key]: value }));
    if (key in errors) {
      setErrors((prev) => {
        const next = { ...prev };
        delete next[key as keyof FoundingFieldErrors];
        return next;
      });
    }
  };

  const toggleRole = (id: FoundingRoleId) => {
    setApp((prev) => ({
      ...prev,
      roles: prev.roles.includes(id)
        ? prev.roles.filter((role) => role !== id)
        : [...prev.roles, id],
    }));
    if (errors.roles) {
      setErrors((prev) => {
        const next = { ...prev };
        delete next.roles;
        return next;
      });
    }
  };

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    const checked = validateFoundingApplication(app);
    if (!checked.ok) {
      setDraft(null);
      setErrors(checked.errors);
      const first = Object.keys(checked.errors)[0];
      document.getElementById(`${formId}-${first}`)?.focus();
      return;
    }
    const next = buildFoundingMailto(DEVELOPER.email, checked.value);
    setErrors({});
    setDraft(next);
    setCopied(false);
    setCopyError("");
    // Opens the visitor's mail client with a draft. Nothing is posted to us.
    window.location.assign(next.href);
  };

  const copyDraft = async () => {
    if (!draft) return;
    const text = `To: ${draft.to}\nSubject: ${draft.subject}\n\n${draft.body}`;
    try {
      await navigator.clipboard.writeText(text);
      setCopyError("");
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopyError("Clipboard blocked. Select the draft below and copy it by hand.");
    }
  };

  return (
    <div className="border border-brand-gray bg-brand-gray-dark/40 rounded paper-card p-6 md:p-10">
      <noscript>
        <p className="mb-6 text-xs text-brand-gray-light leading-relaxed">
          JavaScript is off, so this page cannot open a mail draft. Email{" "}
          <a className="text-white underline" href={`mailto:${DEVELOPER.email}`}>
            {DEVELOPER.email}
          </a>{" "}
          with the subject “NO SUS founding team” and your name, the areas you
          want to cover, links, and what you would bring.
        </p>
      </noscript>

      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label htmlFor={`${formId}-name`} className="text-[10px] font-bold tracking-widest uppercase text-white">
              Name
            </label>
            <input
              id={`${formId}-name`}
              name="name"
              type="text"
              autoComplete="name"
              required
              maxLength={FOUNDING_LIMITS.name}
              value={app.name}
              onChange={(e) => setField("name", clip(e.target.value, FOUNDING_LIMITS.name))}
              aria-invalid={Boolean(errors.name)}
              aria-describedby={errors.name ? `${formId}-name-error` : undefined}
              className={inputClass}
            />
            {errors.name && (
              <p id={`${formId}-name-error`} role="alert" className="mt-1.5 text-[11px] text-white">
                {errors.name}
              </p>
            )}
          </div>

          <div>
            <label htmlFor={`${formId}-email`} className="text-[10px] font-bold tracking-widest uppercase text-white">
              Email
            </label>
            <input
              id={`${formId}-email`}
              name="email"
              type="email"
              autoComplete="email"
              required
              maxLength={FOUNDING_LIMITS.email}
              value={app.email}
              onChange={(e) => setField("email", clip(e.target.value, FOUNDING_LIMITS.email))}
              aria-invalid={Boolean(errors.email)}
              aria-describedby={errors.email ? `${formId}-email-error` : undefined}
              className={inputClass}
            />
            {errors.email && (
              <p id={`${formId}-email-error`} role="alert" className="mt-1.5 text-[11px] text-white">
                {errors.email}
              </p>
            )}
          </div>
        </div>

        <fieldset>
          <legend className="text-[10px] font-bold tracking-widest uppercase text-white">
            Where you would help
          </legend>
          <p id={`${formId}-roles-hint`} className="mt-1 text-[11px] text-brand-gray-light">
            Pick every area that is honest. This is a one-person encrypted-docs
            product, not a hiring pipeline with open requisitions.
          </p>
          <div
            id={`${formId}-roles`}
            role="group"
            tabIndex={-1}
            aria-describedby={`${formId}-roles-hint${errors.roles ? ` ${formId}-roles-error` : ""}`}
            aria-invalid={Boolean(errors.roles)}
            className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-2"
          >
            {FOUNDING_ROLES.map((role) => {
              const checked = app.roles.includes(role.id);
              const boxId = `${formId}-role-${role.id}`;
              return (
                <label
                  key={role.id}
                  htmlFor={boxId}
                  className={`flex items-start gap-3 border px-3 py-3 cursor-pointer ${
                    checked ? "border-white bg-white/5" : "border-brand-gray hover:border-white/40"
                  }`}
                >
                  <input
                    id={boxId}
                    name="roles"
                    type="checkbox"
                    value={role.id}
                    checked={checked}
                    onChange={() => toggleRole(role.id)}
                    className="mt-0.5 accent-white"
                  />
                  <span>
                    <span className="block text-xs font-bold uppercase tracking-wider text-white">
                      {role.label}
                    </span>
                    <span className="block text-[11px] text-brand-gray-light mt-0.5">
                      {role.hint}
                    </span>
                  </span>
                </label>
              );
            })}
          </div>
          {errors.roles && (
            <p id={`${formId}-roles-error`} role="alert" className="mt-1.5 text-[11px] text-white">
              {errors.roles}
            </p>
          )}
        </fieldset>

        <div>
          <label htmlFor={`${formId}-links`} className="text-[10px] font-bold tracking-widest uppercase text-white">
            Links <span className="text-brand-gray-light font-medium normal-case tracking-normal">(optional)</span>
          </label>
          <input
            id={`${formId}-links`}
            name="links"
            type="text"
            inputMode="url"
            maxLength={FOUNDING_LIMITS.links}
            placeholder="GitHub, site, X — whatever you want read"
            value={app.links}
            onChange={(e) => setField("links", clip(e.target.value, FOUNDING_LIMITS.links))}
            className={inputClass}
          />
        </div>

        <div>
          <label htmlFor={`${formId}-why`} className="text-[10px] font-bold tracking-widest uppercase text-white">
            What you would bring
          </label>
          <textarea
            id={`${formId}-why`}
            name="why"
            required
            rows={6}
            maxLength={FOUNDING_LIMITS.why}
            value={app.why}
            onChange={(e) => setField("why", clip(e.target.value, FOUNDING_LIMITS.why))}
            aria-invalid={Boolean(errors.why)}
            aria-describedby={`${formId}-why-count${errors.why ? ` ${formId}-why-error` : ""}`}
            className={`${inputClass} resize-y min-h-[8rem]`}
          />
          <div className="mt-1.5 flex justify-between gap-4">
            {errors.why ? (
              <p id={`${formId}-why-error`} role="alert" className="text-[11px] text-white">
                {errors.why}
              </p>
            ) : (
              <span className="text-[11px] text-brand-gray-light">
                A short note is enough. No pitch deck required.
              </span>
            )}
            <span id={`${formId}-why-count`} className="text-[11px] font-mono text-brand-gray-light shrink-0">
              {app.why.length}/{FOUNDING_LIMITS.why}
            </span>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label htmlFor={`${formId}-location`} className="text-[10px] font-bold tracking-widest uppercase text-white">
              Location / timezone <span className="text-brand-gray-light font-medium normal-case tracking-normal">(optional)</span>
            </label>
            <input
              id={`${formId}-location`}
              name="location"
              type="text"
              autoComplete="off"
              maxLength={FOUNDING_LIMITS.location}
              value={app.location}
              onChange={(e) => setField("location", clip(e.target.value, FOUNDING_LIMITS.location))}
              className={inputClass}
            />
          </div>

          <div>
            <label htmlFor={`${formId}-hours`} className="text-[10px] font-bold tracking-widest uppercase text-white">
              Hours <span className="text-brand-gray-light font-medium normal-case tracking-normal">(optional)</span>
            </label>
            <select
              id={`${formId}-hours`}
              name="hours"
              value={app.hours}
              onChange={(e) =>
                setField("hours", e.target.value as FoundingApplication["hours"])
              }
              className={inputClass}
            >
              {FOUNDING_HOURS.map((row) => (
                <option key={row.id || "none"} value={row.id}>
                  {row.label}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div>
          <label htmlFor={`${formId}-heard`} className="text-[10px] font-bold tracking-widest uppercase text-white">
            How you heard about NO SUS <span className="text-brand-gray-light font-medium normal-case tracking-normal">(optional)</span>
          </label>
          <input
            id={`${formId}-heard`}
            name="heard"
            type="text"
            maxLength={FOUNDING_LIMITS.heard}
            value={app.heard}
            onChange={(e) => setField("heard", clip(e.target.value, FOUNDING_LIMITS.heard))}
            className={inputClass}
          />
        </div>

        <p className="text-[11px] text-brand-gray-light leading-relaxed">
          Open email draft prepares a message to{" "}
          <a className="text-white underline" href={`mailto:${DEVELOPER.email}`}>
            {DEVELOPER.email}
          </a>
          . Nothing is stored in the NO SUS database. The application arrives
          only if you send that email. See the{" "}
          <a className="text-white underline" href={PRIVACY_URL}>
            privacy policy
          </a>
          .
        </p>

        <div className="flex flex-wrap items-center gap-4">
          <button
            type="submit"
            className="inline-flex items-center gap-2 bg-white text-black px-8 py-3.5 text-xs font-bold uppercase tracking-wider hover:bg-black hover:text-white border border-white transition-all rounded-sm"
          >
            <Mail className="h-4 w-4" aria-hidden="true" />
            Open email draft
          </button>
        </div>
      </form>

      {draft && (
        <div
          className="mt-8 border border-white/20 bg-brand-black p-5 flex flex-col gap-3"
          role="status"
        >
          <p className="text-xs text-white font-medium leading-relaxed">
            {draft.truncated
              ? "The note was shortened so it would fit in a mail draft. Send the email from your mail app, or copy the text below."
              : "A draft to the address above should have opened. Send it from your mail app to actually apply. If nothing opened, copy the text below."}
          </p>
          <div className="flex flex-wrap gap-3">
            <a
              href={draft.href}
              className="inline-flex items-center gap-2 border border-white px-4 py-2 text-[10px] font-bold uppercase tracking-widest text-white hover:bg-white hover:text-black transition-colors"
            >
              <Mail className="h-3.5 w-3.5" aria-hidden="true" />
              Open draft again
            </a>
            <button
              type="button"
              onClick={copyDraft}
              className="inline-flex items-center gap-2 border border-white/30 px-4 py-2 text-[10px] font-bold uppercase tracking-widest text-white hover:border-white transition-colors"
            >
              {copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
              {copied ? "Copied" : "Copy draft"}
            </button>
          </div>
          {copyError && (
            <p role="alert" className="text-[11px] text-white">
              {copyError}
            </p>
          )}
          <pre className="mt-1 max-h-64 overflow-auto text-[11px] font-mono text-brand-gray-light whitespace-pre-wrap break-words">
            {`To: ${draft.to}\nSubject: ${draft.subject}\n\n${draft.body}`}
          </pre>
        </div>
      )}
    </div>
  );
}
