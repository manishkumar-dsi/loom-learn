# CLAUDE.md — loom-learn

This file provides guidance for AI assistants (Claude Code and others) working on the **loom-learn** repository. It documents project structure, development workflows, and conventions.

> **Note:** This repository is currently in its initial state with no committed source code. This document will grow alongside the project. Update this file whenever significant architectural or workflow changes are made.

---

## Project Overview

**Repository:** `manishkumar-dsi/loom-learn`
**Branch model:** Feature branches prefixed with `claude/` for AI-assisted work.

*TODO: Add a short description of what loom-learn does once the project goals are defined.*

---

## Repository Structure

Currently empty. Expected structure will be documented here once scaffolding is in place.

```
loom-learn/
├── CLAUDE.md          # This file
├── README.md          # User-facing documentation (create when project is scaffolded)
└── ...                # Source code, tests, config to be added
```

---

## Getting Started

*TODO: Fill in once the project is scaffolded. Include:*
- Prerequisites / runtime versions (Node, Python, etc.)
- Installation steps (`npm install`, `pip install`, etc.)
- Environment variable setup (`.env.example`)
- Running locally

---

## Development Workflow

### Branching

- Main/default branch: determine once first commit is pushed.
- AI-assisted work branches are prefixed with `claude/` (e.g., `claude/feature-name-<session-id>`).
- Never push directly to `main` or `master` without a pull request.

### Commits

- Use clear, imperative commit messages: `Add user authentication`, `Fix pagination bug`.
- Keep commits focused and atomic.
- Reference issue numbers where applicable: `Fix #42: handle empty input`.

### Pull Requests

- PRs should have a summary and a test plan.
- All CI checks must pass before merging.

---

## Commands

*TODO: Fill in once the project build system is in place.*

```bash
# Example placeholders — replace with real commands
npm install          # Install dependencies
npm run dev          # Start development server
npm test             # Run tests
npm run lint         # Run linter
npm run build        # Production build
```

---

## Testing

*TODO: Document the testing framework and conventions once chosen.*

- Preferred framework: TBD
- Test location: TBD (e.g., `src/__tests__/`, `tests/`)
- Coverage requirements: TBD
- Always run tests before committing changes.

---

## Code Style & Linting

*TODO: Document linting/formatting tools once configured.*

- Formatter: TBD (e.g., Prettier, Black, rustfmt)
- Linter: TBD (e.g., ESLint, Ruff, Clippy)
- Follow existing style in any file you edit — consistency over preference.
- Do not reformat files unrelated to your change.

---

## Environment Variables

*TODO: List required environment variables once the project has config.*

Create a `.env` file from `.env.example` (to be added):

```
# Example
# DATABASE_URL=
# API_KEY=
```

Never commit `.env` files or secrets to the repository.

---

## Key Conventions for AI Assistants

1. **Read before editing.** Always read a file before modifying it. Never guess at file contents.
2. **Minimal changes.** Only change what is necessary for the task. Do not refactor, reformat, or add unrelated improvements.
3. **No invented abstractions.** Do not create helpers or utilities unless the current task requires them.
4. **No speculative features.** Implement only what is explicitly requested.
5. **Security first.** Never introduce SQL injection, XSS, command injection, or other OWASP Top 10 vulnerabilities. Validate at system boundaries only.
6. **No secrets in code.** Use environment variables for all credentials and API keys.
7. **Test your changes.** Run the test suite after making changes. Do not commit if tests fail.
8. **Commit on feature branches.** Use the designated `claude/` branch for AI work. Never push to main without a PR.
9. **Update this file.** When you add major features, change the stack, or alter workflows, update CLAUDE.md accordingly.
10. **Ask before destructive actions.** Confirm before deleting files, dropping data, force-pushing, or any irreversible operation.

---

## Architecture Notes

*TODO: Document key architectural decisions, patterns, and third-party integrations once the project is built.*

---

## CI/CD

*TODO: Document CI/CD pipeline once configured.*

---

*Last updated: 2026-02-25 (initial creation — empty repository)*
