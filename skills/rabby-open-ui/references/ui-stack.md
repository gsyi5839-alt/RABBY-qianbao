# UI stack and tokens

## Shared UI
- packages/ui: ThemeProvider, tokens, and shared components.
- Theme tokens are CSS variables with --r-* and --rb-* prefixes.

## Extension UI
- src/ui uses Ant Design 4, styled-components, and Tailwind.
- Prefer existing components and patterns; avoid introducing new UI libs.

## Web and Admin
- apps/web and apps/admin are Vite + React 18.
- Use packages/ui as the primary shared layer.
- Client services live under apps/web/src/services and apps/admin/src/services.

## Tailwind
- tailwind.config.js defines spacing, fonts, and Rabby color tokens.
