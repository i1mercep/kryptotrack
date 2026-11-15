<div align="center">

<picture>
  <source media="(prefers-color-scheme: light)" srcset="contents/images/kryptotrack_light.svg">
  <img alt="kryptotrack logo" src="contents/images/kryptotrack_dark.svg" width="25%" height="25%">
</picture>

**kryptotrack**: Effortlessly monitor the current cryptocurrency price with this lightweight Plasma 6 applet.

[![plasma](https://img.shields.io/static/v1?message=KDE%20Store&color=54a3d8&logo=kde&logoColor=FFFFFF&label=Kryptotrack)][kdestore]
[![GitHub Repo stars](https://img.shields.io/github/stars/i1mercep/kryptotrack)](https://github.com/i1mercep/kryptotrack/stargazers)
[![downloads](https://img.shields.io/github/downloads/i1mercep/kryptotrack/total)][releases]
[![release](https://img.shields.io/github/v/release/i1mercep/kryptotrack)][releases]
[![license](https://img.shields.io/github/license/i1mercep/kryptotrack)](https://github.com/i1mercep/kryptotrack/blob/main/LICENSE)

</div>

---

## Requirements

Plasma **6.8+**, Qt **6.12+**, and KDE Frameworks **6.31+**, including the
Kirigami, KCMUtils, and Prison QML modules. Prison renders donation QR codes locally.
The widget remains a directly installable QML/JavaScript package; no compiler,
Node.js, Bun, or TypeScript is needed to run it.

## Installation

Build/install with `just install` (requires `just`, `zip`, `ripgrep`, and
`kpackagetool6`), or install a release `.plasmoid` through Plasma's widget installer.
Existing configuration keys and defaults are preserved. This release raises the
minimum supported desktop stack; older Plasma installations need an older release.

Installation does not restart your desktop. Remove/re-add the widget to load new
code, or explicitly run `just restart-plasma`. Uninstall with `just uninstall`.

## Usage and data providers

The widget shows one cryptocurrency price, optionally with the base currency and
24-hour percentage change. Right-click **Refresh** to request an update. The last
valid price stays visible during refreshes; a warning indicator and tooltip explain
failures or stale data. The tooltip identifies the actual provider and update time.
A quote is considered stale after a failed request or when its source timestamp is
older than the greater of two refresh intervals and two minutes.

- **Binance** is the default public Spot provider; no key is required. `USDT` is the
  default quote currency.
- Unsupported Binance pairs fall back to **CoinGecko** when the coin can be
  identified. Duplicate symbols are not resolved by picking an arbitrary match;
  select the exact coin using the CoinGecko catalog if a mapping is ambiguous.
- The optional **CoinGecko Pro** key also applies to fallback requests. It is sent
  in a request header. The existing Plasma configuration storage is unchanged.
- Timeouts and transient failures receive up to two retries per endpoint. Both
  polling and manual refresh honor server cooldowns. A regular poll never aborts
  an active request.
- Settings search changes the selection only when a result is activated. Searching,
  moving focus, or updating a catalog preserves the saved selection. The bundled
  catalog remains available when the network catalog fails.

## Development

Install Bun **1.4.4+**, Qt 6 development tools, and `plasma-sdk` for the viewer:

```bash
bun install --frozen-lockfile
just check       # JS/QML lint, checked JS, unit/native tests, package validation
just run         # plasmoidviewer with the working tree
just format      # explicit in-place formatting
```

`just lint`, `just typecheck`, and `just test` run individual checks. The Qt tools
must be version 6.12 or newer; set `QT6_BIN_DIR` if they are installed outside the
usual Qt 6 directories. This avoids accidentally running Qt 5 tools from PATH.
`just build` packages only runtime assets. Generated artifacts live in `build/`
and the ignored `kryptotrack.plasmoid` archive.

CI runs `bun run check` and validates the archive before the existing tagging and
release jobs. Native Qt/KDE tests run through `just check` on the supported desktop
stack; the generic GitHub runner does not claim that coverage.

### Architecture

`main.qml` binds presentation to a per-widget `PriceController`. The controller
owns lifecycle and timers; `providerRouter.mjs` coordinates cancellable operations,
retries, fallback, and identity-scoped quotes. Provider modules build requests and
parse responses without touching UI objects. Formatting and catalog selection are
pure modules. Mutable request state is never shared between widget instances.

JavaScript uses ES modules and JSDoc contracts checked with TypeScript, without a
transpilation step. Qt's JavaScript runtime is not a browser: native tests verify
supported syntax and HTTP behavior. In particular, `RequestScheduler.send()` keeps
XHR dispatch in the owning QML context; explicit timers implement deadlines.
The large bundled coin catalog is imported only by settings, not the panel ticker.

### Validation and desktop acceptance

Bun tests use a deterministic clock and transport to exercise formatting, identity,
fallback, cancellation, retries, and cooldowns. Qt Quick tests exercise the actual
QML engine, settings components, locale formatting, and native XHR against a local
HTTP fixture. They do not depend on live provider availability.

Before releasing, check the widget on the supported desktop with:

```bash
plasmoidviewer -a . -f horizontal -l topedge -s 420x64
plasmoidviewer -a . -f vertical -l leftedge -s 80x240
plasmoidviewer -a . -f planar -s 320x180
```

Confirm readable text in Breeze light/dark at normal and fractional scale, keyboard
search/activation and focus order, settings Apply/Cancel, initial loading, refresh
with a retained price, stale/error tooltips, and recovery after a connection outage.
Check donation QR display/copy feedback and two independent widget instances.
Offscreen tests and viewer startup checks do not establish physical panel behavior,
screen-reader output, or interactive settings Apply/Cancel acceptance.

## Support the project

* ₿ Bitcoin [bc1pctjprf84cfeljfn3a4d8ptkra8f8smnz9eyvt4j5f84j6dlerwzqrgsq3u](https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=bc1pctjprf84cfeljfn3a4d8ptkra8f8smnz9eyvt4j5f84j6dlerwzqrgsq3u) (taproot)
* Ξ Ethereum [0xA3322B8FB1342FD8B6796cC9d4cCbCF56CB5D783](https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=0xA3322B8FB1342FD8B6796cC9d4cCbCF56CB5D783)
* ◎ Solana [Cs2d9otY51KkdPqA23xtRyY2vXFA7U3pxKg2oNvGKWNN](https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=Cs2d9otY51KkdPqA23xtRyY2vXFA7U3pxKg2oNvGKWNN)
* Quai [0x0024826B61a2c3D6C83a5eF3A3D5D31551BB1Fe4](https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=0x0024826B61a2c3D6C83a5eF3A3D5D31551BB1Fe4)

[kdestore]: https://store.kde.org/p/2297595
[releases]: https://github.com/i1mercep/kryptotrack/releases
