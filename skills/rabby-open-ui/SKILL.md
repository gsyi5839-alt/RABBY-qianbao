---
name: rabby-open-ui
description: Open-source UI and design-system guidance for Rabby. Use when building or refactoring UI in the extension, web app, or admin console; choose components from packages/ui, Ant Design, Tailwind, and styled-components while following design tokens and theme rules.
---

# Rabby Open UI Toolkit

## Overview
Use this skill to build consistent UI across extension, web, and admin surfaces using the repo open-source stack and design tokens.

## Workflow
1. Check for existing shared components in packages/ui. Reuse or extend before adding new ones.
2. For extension UI (src/ui), use existing patterns and Ant Design 4 where already in use.
3. For web/admin (apps/web, apps/admin), prefer packages/ui plus local components.
4. Style using design tokens (CSS variables) and the Tailwind spacing and typography scale.
5. Keep light and dark mode support via ThemeProvider and CSS variables.

## Component placement rules
- Reusable across web/admin: add to packages/ui.
- Extension-only: keep under src/ui/components.
- One-off page elements: local component in app.

## References
- Read references/ui-stack.md for specific libraries, tokens, and file locations.
- Use docs/ui-ux-design.md for page-level layout and visual spec.
