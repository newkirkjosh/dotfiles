---
name: improve-codebase-architecture
description: Scan a codebase for deepening opportunities, present them as a visual HTML report, then interview the user through whichever one they pick.
disable-model-invocation: true
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This command is built on the shared design vocabulary in the `codebase-design` skill (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Use these terms exactly in every suggestion — don't drift into "component," "service," "API," or "boundary."

Ground the review in whatever this project already uses to record domain language and past decisions — a `CONTEXT.md`-style glossary, ADRs under `docs/adr/`, OpenSpec change folders, or a `CLAUDE.md`/`AGENTS.md` Structure section. Check what exists before assuming a format; don't invent a new one just for this skill.

## Process

### 1. Explore

Read whatever domain glossary and past-decision records the project already keeps, in the area you're touching, before looking at code.

Then use the Agent tool with `subagent_type=Explore` to walk the codebase. Don't follow rigid heuristics — explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the OS temp directory so nothing lands in the repo. Resolve the temp dir from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows), and write to `<tmpdir>/architecture-review-<timestamp>.html` so each run gets a fresh file. Open it for the user — `xdg-open <path>` on Linux, `open <path>` on macOS, `start <path>` on Windows — and tell them the absolute path.

The report uses **Tailwind via CDN** for layout and styling, and **Mermaid via CDN** for diagrams where a graph/flow/sequence reliably communicates the structure. Mix Mermaid with hand-crafted CSS/SVG visuals — use Mermaid when relationships are graph-shaped (call graphs, dependencies, sequences), and hand-built divs/SVG when you want something more editorial (mass diagrams, cross-sections, collapse animations). Each candidate gets a **before/after visualisation**. Be visual.

For each candidate, render a card with:

- **Files** — which files/modules are involved
- **Problem** — why the current architecture is causing friction
- **Solution** — plain English description of what would change
- **Benefits** — explained in terms of locality and leverage, and how tests would improve
- **Before / After diagram** — side-by-side, custom-drawn, illustrating the shallowness and the deepening
- **Recommendation strength** — one of `Strong`, `Worth exploring`, `Speculative`, rendered as a badge

End the report with a **Top recommendation** section: which candidate you'd tackle first and why.

**Use the project's own domain vocabulary for the domain, and the `codebase-design` vocabulary for the architecture.** If the project's glossary defines "Order," talk about "the Order intake module" — not "the FooBarHandler," and not "the Order service."

**Conflicts with a past decision**: if a candidate contradicts an existing ADR/design doc, only surface it when the friction is real enough to warrant revisiting that decision. Mark it clearly in the card (e.g. a warning callout: _"contradicts the daemon-language decision in ADR-0001 — but worth reopening because…"_). Don't list every theoretical refactor a past decision forbids.

See [HTML-REPORT.md](HTML-REPORT.md) for the full HTML scaffold, diagram patterns, and styling guidance.

Do NOT propose interfaces yet. After the file is written, ask the user: "Which of these would you like to explore?"

### 3. Interview loop

Once the user picks a candidate, walk the design tree with them through a relentless interview — constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive. Don't accept the first answer at face value; keep pushing on ambiguity and edge cases until the shape is concrete. Use the `superpowers:brainstorming` skill's spirit for this if it's already loaded, or just run the interview inline — the point is depth of questioning, not a specific skill.

Side effects happen inline as decisions crystallize — keep the project's own domain/decision records current as you go, in whatever format it already uses:

- **Naming a deepened module after a concept not yet recorded anywhere?** Add the term to the project's glossary (`CONTEXT.md`, a CLAUDE.md section, or equivalent). Create it lazily if the project doesn't have one yet, asking the user where it should live first.
- **Sharpening a fuzzy term during the conversation?** Update that record right there.
- **User rejects the candidate with a load-bearing reason?** Offer to record the decision so future architecture reviews don't re-suggest it — as an ADR, an OpenSpec design.md note, or whatever the project already uses for this. Only offer when the reason would actually be needed by a future explorer to avoid re-suggesting the same thing — skip ephemeral reasons ("not worth it right now") and self-evident ones.
- **Want to explore alternative interfaces for the deepened module?** Run the `codebase-design` skill's design-it-twice parallel sub-agent pattern (see `DESIGN-IT-TWICE.md`).
