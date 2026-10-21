# End-to-end tests

A test app and a driver that run the SDK on an iOS simulator against a real
LinkForty server. Each scenario installs the app fresh, opens a link in Safari,
launches and relaunches the app, and checks two things: what the SDK handed the
app, and (with a database URL) what the server stored. The expectations are the
documented behavior in the README, `API.md` and the SDK specification.

| Scenario | Checks |
|---|---|
| Attributed install | Click → install → deferred deep link once, with parameters, path and `clickedAt`; three relaunches report no install and deliver nothing; one install stored; the configured attribution window is sent |
| Organic install | `onDeferredDeepLink(nil)` once (needs `LF_E2E_ORGANIC_APP_TOKEN`) |
| Callbacks before `initialize` | They receive the deferred deep link |
| Link while running | `onDeepLink` once, resolved by the server, stored and URL parameters merged |
| Link that launches the app | `onDeepLink` once |
| Events | 4 tracked → 4 stored, nothing left queued |
| Offline first launch | `initialize()` can be retried in the same session; one install stored |
| Concurrent `initialize` | One install stored |
| `createLink` | Returns a link that resolves with its parameters; the same user and parameters return the same link (needs `LF_E2E_API_KEY`) |
| Non-string parameters | A link with numeric and boolean parameters still delivers its deep link |
| `clearData()` | Callbacks still fire; the next launch is a first launch and reports a new install |

## Requirements

- Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and Node 18+
- A LinkForty server, local or remote, that trusts `X-Forwarded-For`
  (Fastify `trustProxy`, or Core's `TRUSTED_CLIENT_IP_HEADER=x-forwarded-for`)
- `psql`, for the database checks (optional)

## Run

```bash
export LF_E2E_BASE_URL=http://localhost:3000        # the server (default)
export LF_E2E_API_KEY=...                           # creates the test links
export LF_E2E_APP_TOKEN=...                         # if the server scopes installs by app token
export LF_E2E_ORGANIC_APP_TOKEN=...                 # a workspace with no clicks, for the organic scenario
export LF_E2E_DATABASE_URL=postgresql://...         # enables the database checks

node E2E/run.mjs                 # builds the app, then runs every scenario
node E2E/run.mjs --no-build      # reuses the last build
LF_E2E_ONLY="events" node E2E/run.mjs --no-build   # scenarios whose name contains "events"
```

The driver creates (or reuses) a simulator named `LinkForty E2E` on the newest
installed iOS runtime; set `LF_E2E_SIMULATOR` to use another. It writes a JSON
report to `E2E/build/e2e-report.json` and exits non-zero if any check fails.

## How it works

- **The app** (`App/LFE2EApp.swift`) integrates the SDK as the README does and
  appends everything the SDK hands it (`initialize` results, callbacks, the
  thread they ran on) to `Documents/lfe2e.jsonl`.
- **The driver** (`run.mjs`, with `harness.mjs` and `scenarios.mjs`) installs and
  launches the app with `simctl`, writes its config into the app's container, and
  sends commands (track an event, create a link, clear data) by appending to
  `Documents/lfe2e-commands.jsonl`, which the app polls. iOS asks before opening
  an app from a custom-scheme URL, so URLs can't carry commands. A link that
  launches the app is passed as a launch argument and handed to the SDK as
  `onOpenURL` would.
- **Attribution needs a public IP.** The server ignores loopback and private
  addresses when matching an install to a click, so the device talks to the
  server through a proxy in the driver that sets `X-Forwarded-For`. Each scenario
  gets its own address, which also keeps one scenario's clicks from matching
  another's install.

`scenarios.mjs` and `harness.mjs` are shared with the Android SDK's harness.
