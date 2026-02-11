# Repository Guidelines

## Project Structure & Module Organization
- `src/` holds the main TypeScript/React code, organized by extension context (e.g., `background/`, `content-script/`, `ui/`, `utils/`, `manifest/`).
- `__tests__/` contains Jest tests and shared setup in `__tests__/setupTests.ts`.
- `_raw/` stores static assets such as locales, images, fonts, and sounds.
- `build/` contains webpack/build tooling and release scripts.
- `docs/` is project documentation; `audits/` contains security audit reports.
- `dist/` is the compiled extension output after builds.

## Build, Test, and Development Commands
Use Yarn (package manager set to `yarn@1.22.22`). The repo declares Node `>=22` in `package.json`; README mentions 14+. Prefer Node `>=22` for consistency, and note the README may be stale.

- `yarn` installs dependencies.
- `yarn build:dev` builds a Chrome MV3 dev bundle (watch mode).
- `yarn dev` builds with type-checking enabled.
- `yarn dev:hot` starts the hot-reload dev server.
- `yarn build:pro` builds a production bundle into `dist/`.
- `yarn build:debug` builds a debug bundle.
- `yarn test` runs Jest.
- `yarn lint:fix` runs ESLint with autofix.

## Coding Style & Naming Conventions
- ESLint with `@typescript-eslint` and `react-hooks` is enabled; Prettier enforces formatting.
- Formatting: 2-space indentation, single quotes, trailing commas where valid (`.prettierrc`).
- Tests follow `*.test.ts` naming and live under `__tests__/`.

## Testing Guidelines
- Jest + `ts-jest` with `jest-environment-jsdom`.
- Tests are discovered via `__tests__/**/*.test.ts`.
- No explicit coverage thresholds; add or update tests when changing behavior.

## Rules & Expectations
- Use Yarn for dependency changes; keep `yarn.lock` in sync with `package.json`.
- Prefer editing source in `src/` and regenerate `dist/` via build scripts instead of manual edits.
- Run `yarn lint:fix` and `yarn test` for non-trivial changes before opening a PR.

## Commit & Pull Request Guidelines
- Git history only shows an “Initial commit,” so adopt a clear convention going forward.
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `build:`, `ci:` (e.g., `fix: handle swap quote timeout`).
- PRs should include: what/why, test commands run, and screenshots for UI changes. Link related issues when applicable.

## Security & Configuration Notes
- Security audit PDFs are in `audits/`; security policies are in `SecSDK/`.
- Never commit secrets, private keys, or wallet data.
