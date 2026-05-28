# On-Device Translation POC

A proof-of-concept iOS app that **translates network responses to English on-device, at the network parse layer**, using Apple's Translation framework — purely to improve **developer experience**.

> ⚠️ **This is a developer tool, not a production feature.** It exists so non-Korean developers can read a Korean-first app while debugging. It is not meant to ship to end users.

---

## 1. Problem

The primary app is **Korean-first**. The backend sometimes returns content with **no English translation at all**. Developers who don't read Korean get stuck — they can't tell what a screen is showing, what a button does, or what an error means.

We want those developers to see a **mostly-English** version of the app while they work, without changing the backend or the feature code.

## 2. Approach

Translate everything **as it enters the app**, transparently:

- Plug into the **single layer where responses are parsed**, so every screen benefits with zero per-screen work.
- Rule: **"translate anything that isn't already English → English."** Models stay plain `Codable` with **no annotations**.
- Start with **Apple's on-device Translation framework**, but keep it behind a **provider abstraction** so another engine (e.g. Google ML Kit) can be dropped in later.
- Everything is **on-device** and **off the main thread**; the UI just shows a normal loading state while a response is being translated.

## 3. Final solution / How it works

```
ViewModel ── APIClient.fetch<T>(endpoint)
                 │  1. NetworkService → Data        (remote raw-GitHub URL, or bundled JSON)
                 │  2. ResponseTranslator.translate(Data) → Data   ← THE PLUG-IN POINT
                 │  3. JSONDecoder.decode(T)         (plain Codable, untouched)
                 ▼
            translated typed model → SwiftUI

ResponseTranslator (actor — runs off the main thread, never throws):
   Data → JSONValue tree → collect string leaves
        → TranslationFilter rule engine (skip URLs / IDs / numbers / dates / denylisted keys)
        → NLLanguageRecognizer (skip English & undetermined) → dedupe → GROUP by source language
        → TextTranslator.translate(group)  [TranslationCache] → rebuild tree → Data
        + TranslationStats (original→translated, language, cache-hit) for the Debug panel

TextTranslator (protocol) ── AppleTextTranslator ── TranslationCoordinator (@MainActor)
                                                          ▲ session vended by
                                                  TranslationHostView (.translationTask, hidden at app root)
```

Key design points:

- **Generic JSON-tree walk.** Because the rule is "translate everything not English," translation happens on the raw JSON before decoding. `JSONValue` preserves **object key order** and **numeric precision**, and **only string leaf-values that pass the rule engine are ever rewritten** — keys, numbers, booleans, null, and structure are byte-faithful. On any failure the original data is returned, so the schema (and decoding) can never break.
- **A small ordered rule engine** (`TranslationFilter`) runs cheapest-first and short-circuits, skipping obvious non-content (URLs, IDs/UUIDs, slugs, pure numbers, ISO dates, denylisted keys like `id`/`url`/`imageUrl`) *before* the more expensive per-string language detection.
- **Grouping by detected language.** Apple's batch API can't mix source languages, so strings are grouped per detected language and translated one batch per language, with an in-memory cache.
- **The SwiftUI-bound session bridge.** `TranslationSession` can only be obtained inside a view's `.translationTask`. A hidden, zero-size `TranslationHostView` at the app root vends sessions to a `@MainActor` `TranslationCoordinator`, which exposes a plain `async translate()` the network layer awaits. This keeps networking SwiftUI-agnostic and lets a non-SwiftUI provider drop in later.

## 4. Project overview

```
OnDeviceTranslate/OnDeviceTranslate/
  App/                     OnDeviceTranslateApp wiring · RootTabView · TranslationStatusBadge
  Translation/             ← the core; self-contained, extractable as an SPM package
    Core/                  TextTranslator (protocol) · TranslationFilter (rule engine) ·
                           LanguageDetection · TranslationCache · TranslationStats
    Pipeline/              JSONValue (order/precision-preserving) · ResponseTranslator
    Apple/                 AppleTextTranslator · TranslationCoordinator · TranslationHostView ·
                           TranslationAvailability
    TranslatorFactory.swift
  Networking/              Endpoint · NetworkService (remote + bundle fallback) · APIClient
  DebugSettings/           DebugSettings (UserDefaults store) · DebugSettingsView
  Features/                Feed/ · Detail/ · Profile/   (each: View + ViewModel)
  Models/                  Plain Codable response models · LoadState
  Resources/MockData/      Bundled JSON copies (offline fallback)

api/                       feed.json · detail.json · profile.json  (raw-URL data source)
```

The `Translation/` folder has no dependency on the app, networking, or debug code — only the Apple-specific corner imports `Translation`/SwiftUI. It can be lifted into a Swift package as-is.

## 5. How to run

1. Open `OnDeviceTranslate/OnDeviceTranslate.xcodeproj` in Xcode 16+.
2. **Select a physical iPhone/iPad** as the run destination. The Translation framework **does not work in the Simulator** — on the Simulator the app runs fine but the translation toggle is disabled with a warning.
3. Build & run. On first translation, iOS may prompt to **download the Korean language model** (one-time, on-device afterwards).
4. Open the **Debug** tab → turn on **On-the-fly translation**. Feed / Detail / Profile now render in English.
5. **Data source:** by default the app loads the **bundled** JSON (offline). To fetch live from GitHub, push this repo, set `NetworkConfig.rawBaseURL` in `Networking/Endpoint.swift` to your raw URL (e.g. `https://raw.githubusercontent.com/<user>/on-device-translation-poc/main/`), then turn **off** "Use offline (bundled) JSON" in the Debug tab.

## 6. Constraints & gotchas

- **Real device required** — Apple's Translation framework does not run in the Simulator.
- **`TranslationSession` is SwiftUI-bound** — hence the host-view + coordinator bridge.
- **Batches can't mix source languages** — handled by grouping per detected language.
- **First use downloads a language model** — needs network once; translation is on-device after.
- Translation is **value-keyed**: identical source strings translate consistently across the response.

## 7. Debug Settings

- **On-the-fly translation** — master switch (disabled with a warning when unsupported).
- **Provider** — Apple (live); Google ML Kit (future-scope stub).
- **Language** — source (Auto-detect / Korean) and target (English / Spanish / Japanese / French).
- **Data Source** — toggle bundled-offline vs remote raw-URL.
- **Cache** — enable/disable, view entry count, clear.
- **Last Response Stats** — total / translated / skipped / cache hits / processing time.
- **Translation Log** — "show original + translated" with detected language and cache-hit markers.

All settings persist in `UserDefaults`.

## 8. Edge cases covered (in the mock JSON)

Pure Korean · Korean+English mixed in one string · Japanese / Chinese / Spanish / Arabic (RTL) · already-English (passes through untouched) · emoji · prices (`₩29,000`) · URLs and `imageUrl` (skipped) · IDs / slugs (skipped) · ISO dates (skipped) · empty strings · long paragraphs · nested arrays/objects · a code block.

## 9. Future scope

- Real **Google ML Kit** provider behind the same `TextTranslator` protocol.
- Richer **language selection** and per-field overrides.
- **Persisted** translation cache across launches.
- Production hardening (this POC deliberately optimizes for developer experience, not shipping).
