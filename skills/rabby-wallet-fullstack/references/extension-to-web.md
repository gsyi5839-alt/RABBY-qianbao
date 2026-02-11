# Extension to Web migration patterns

## Storage and messaging
- chrome.storage -> API persistence + localStorage fallback
- chrome.runtime.sendMessage/connect -> REST endpoints or WebSocket
- Extension permissions -> web auth/session + server-side checks

## UI mapping
- Popup pages -> full-page routes or modals
- Notification windows -> modal/toast in web
- Keep ThemeProvider + CSS variable tokens in place

## Data flow checklist
1. Identify state source and side effects.
2. Decide client vs server responsibility.
3. Update shared types in packages/shared.
4. Update API handlers in apps/api.
5. Update client services and UI routes.
6. Add tests or smoke steps for the new flow.

## Security guardrails
- Never send raw seed phrases or private keys to the server.
- Store only encrypted vault data if persistence is required.
- Keep signing on the client unless the user explicitly requests server-side signing.
