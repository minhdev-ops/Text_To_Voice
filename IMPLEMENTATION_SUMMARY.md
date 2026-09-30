# Implementation Summary

## Phase 1 (Text → Vietnamese Speech) — complete, with the real engine

The `VieNeuOnnxTtsEngine` path is implemented and **proven against the real checkpoint on Linux
desktop** (2026-09-29). An earlier version of this file described a skeleton with a silent-audio
fallback waiting for a checkpoint; that state no longer exists. The design of record is
`docs/superpowers/specs/2026-09-28-vieneu-tts-integration-design.md`; the phase checklist lives in
`document/ROADMAP.md`.

### What the engine is now

- **Real on-device synthesis** (FR-09 / NFR-01): sea-g2p FFI phonemizer (C ABI v1 — no Dart
  reimplementation) → byte-level BPE → prompt rows with real speaker conditioning → prefill →
  KV-cache decode loop → acoustic decoder → MOSS codec → 16-bit 48 kHz mono WAV written to the
  synthesis cache.
- **Four ONNX graphs in one worker isolate** via `flutter_onnxruntime` (channel-based binding;
  `BackgroundIsolateBinaryMessenger` is re-initialized inside the worker; KV-cache tensors stay
  native and are handed back, never copied).
- **No silent fallback anywhere.** Missing model → `ModelUnavailableFailure` (offers Install);
  graph loads but cannot run → `CorruptModelFailure` (offers Re-download, FR-20); a bad sentence →
  `ProcessingFailure`, skipped so the rest of the document still plays. Readiness is install
  state, never I/O during `build`.
- **Real voices.** `assets/voices/voices_v3_turbo.json` carries actual speaker embeddings and
  reference codes; the earlier fake hash-based embeddings were deleted, not kept as a fallback.
- **Model delivery is download + verify** (FR-20): `VieNeuModelManifest` holds measured sha256
  digests for every artifact; `ModelDownloadService` / `ModelInstallService` implement progress,
  cancel (drops `.part`), verify and delete; the Models tab renders all six states with the
  license line on the row (SRS §47). Nothing model-sized ships in the APK — only the 180 KB voice
  catalog is bundled.
- **Which engine is live is decided by install state** (`ttsEngineProvider` watching
  `modelReadyProvider`), so install/delete takes effect without an app restart. There is no
  provider override in `main.dart` and none is needed.

### Proof

- `flutter test`: **459 passing**. `flutter analyze lib`: **0 errors** (49 pre-existing
  infos/warnings).
- **Tagged e2e** — `integration_test/vieneu_model_e2e_test.dart` (tag `model`, declared in
  `dart_test.yaml`):
  `tool/fetch_model.sh` → `flutter test integration_test -d linux --tags model`
  "Xin chào Việt Nam" → 48 kHz mono 16-bit WAV, 960 ms, rms 3609 / peak 22142 (the Python
  reference run produced rms ≈ 3480 on the same sentence), and a second request served from cache
  without re-synthesis.

### Still open (tracked in the spec and ROADMAP, not here)

- Android: the sea-g2p `.so` must be built with `tool/build_g2p.sh` (cargo-ndk) — upstream ships
  no Android artifact; on-device listening pass + RTF measurement (spec §9.3) post-handoff.
- fp32 model row, Nano codec row, MP3 export, search, low-memory mode: sub-project D (Phase 6).
