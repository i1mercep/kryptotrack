# Copilot Instructions for `kryptotrack`

## Project Overview
- This project is a KDE Plasma widget (plasmoid) for tracking cryptocurrency data.
- UI is QML-first (`contents/ui/**`), with JavaScript helpers in `contents/code/**`.
- Keep implementations lightweight, readable, and consistent with existing Plasma/QML patterns.

## Architecture Guidelines
- Prefer keeping business/data logic in `contents/code/*.js` and UI/state wiring in QML.
- Reuse existing modules (e.g. `coingecko.js`, `cachedCoins.js`, `cryptoSymbols.js`) before adding new files.
- For settings:
	- Add schema entries in `contents/config/main.xml`.
	- Add/edit controls in `contents/config/config.qml` and related `contents/ui/config/*.qml` pages.
	- Keep setting keys consistent across XML and QML.

## Coding Style
- Match existing style in each file (naming, spacing, import ordering, property style).
- Keep changes minimal and focused; avoid broad refactors unless explicitly requested.
- Prefer descriptive names over short/ambiguous ones.
- Do not add dependencies unless necessary.

## QML/Plasma Conventions
- Keep bindings simple and reactive; avoid imperative updates when property bindings are sufficient.
- Avoid expensive work in frequently evaluated bindings.
- Use `Connections`, timers, and async update patterns carefully to avoid duplicate requests.
- Preserve responsiveness for small widget sizes.

## Data/API Handling
- Coin/data fetching should be robust to network failures and partial API responses.
- Gracefully handle missing/null values in UI and JS logic.
- Respect existing caching behavior and update intervals.
- If changing API request/response handling, update all affected call sites.

## Scope & Safety
- Do exactly what is requested—no extra features, no unrelated redesigns.
- Do not rename public setting keys, files, or component IDs unless requested.
- Keep backward compatibility for user configuration whenever possible.

## Validation Checklist (before finishing)
- Confirm modified QML files remain valid and imports are correct.
- Confirm changed setting keys exist in both XML schema and config UI.
- Sanity-check that main widget UI still loads and default state behaves safely.
- If behavior changed, briefly document why in the final response.
