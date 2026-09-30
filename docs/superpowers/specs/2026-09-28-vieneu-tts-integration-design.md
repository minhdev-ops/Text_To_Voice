# VieNeu-TTS v3 Turbo Integration — Design Spec

- Date: 2026-09-28
- Status: IMPLEMENTED (approved and built; desktop e2e gate passed 2026-09-29 — see Definition of done. Android device pass §9.3 remains post-handoff: no device available, and the g2p Android `.so` still needs `tool/build_g2p.sh`)
- Scope: Sub-project A only (VieNeu engine + Model Manager). Phase 3 (PDF), Phase 4 (Extraction), Phase 6 remainder are separate spec cycles in that order.
- License gate: checkpoints Apache-2.0 (SRS §47) — verified on HF/GitHub before this spec.

## 1. Goal

Replace the current non-functional TTS path with real on-device synthesis (FR-09 / NFR-01):

- Model: **VieNeu-TTS v3 Turbo, int8 export** (user choice: int8 first; fp32 later as second option).
- Real audio from Vietnamese text on **CPU only**, sentence at a time (FR-12), through the existing `TtsEngine` seam and sentence queue — no widget/API changes beyond the Models tab and engine wiring.
- Model delivery: **downloaded + verified** per FR-20 (not bundled in the APK).
- Everything works offline after install; network is used only for the model download.

## 2. Current state (inventory)

Existing scaffolding (uncommitted work from an earlier session) — kept where sound, fixed where not:

| Piece | State | Verdict |
|---|---|---|
| `lib/ai/onnx/onnx_model_host.dart` | Worker isolate, `start()` + `run(inputs) → Map<String, OnnxTensor>` | **Keep, extend** (multi-session lifetime, KV-cache tensors, external-data `.data` next to graphs) |
| `lib/ai/tts/vieneu_onnx_tts_engine.dart` (482 L) | Full pipeline skeleton: tokenizer → prefill → decode loop → acoustic → codec → WAV | **Rewrite internals** against the reference; public `TtsEngine` contract unchanged |
| `lib/ai/tts/vieneu_tokenizer.dart` (199 L) | BPE from `tokenizer.json` (vocab + merges + added_tokens) | **Verify + fix** with golden tests (byte-level pre-tokenizer semantics must match HF `tokenizers`) |
| `lib/ai/tts/vieneu_speaker_embeddings.dart` | Fake **hash-based pseudo-embeddings** ("in production, replace") | **Delete** — replaced by real `voices_v3_turbo.json` assets |
| `lib/ai/tts/model_asset_manager.dart` | Copies model from Flutter asset bundle to `<docs>/models/` | **Replace** with download-based `ModelInstallService` |
| `assets/models/**` + pubspec assets (~207 MB) | int8 files staged locally; **incomplete** (missing `moss_audio_tokenizer_decode_shared.data` — required by `decode_full.onnx`) and includes unused cloning files (`speaker_encoder.onnx`, `encode.onnx/.data`) | **Remove from pubspec + gitignore dir**; keep the local files as the dev-time download cache |
| `ttsEngineProvider` (`read_aloud_providers.dart:25`) | Hardcoded `const ModelMissingTtsEngine()` | **Wire** to model state |
| `models` drift table (SRS §35) | uuid, engineId, checkpointName, version, license, sizeBytes, filePath, isInstalled, isActive, checksum, installedAt | **Reuse as-is** — no schema change |
| Tests | `test/ai/onnx/onnx_model_host_test.dart` only | Expand per §9 |

Known-correctness gaps vs reference (why output is currently silent/garbage): no sea-g2p phonemization, no audio prompt/ref rows, no `vieneu_v3_heads.npz` (tied embeddings + `xvec_proj`), prompt build not per `build_prompt_2d`, sampling without repetition penalty, missing codec external-data file.

## 3. Architecture (approved Section 1)

```
Tab Mô hình → ModelManagerScreen → modelInstallStateProvider (Notifier)
   notInstalled → downloading(bytes) → verifying → installed | corrupt | error
        │                                        │
 ModelDownloadService  →  <docs>/models/vieneu-v3-turbo-int8/…
        │                                        │
   models table (drift)  ◄───────────────────────┘

ttsEngineProvider ──watch──► installed ? VieNeuOnnxTtsEngine
                              : ModelMissingTtsEngine   (no restart needed)

synthesize(text, options) in worker isolate:
  sea_g2p FFI phonemize → BPE encode → prompt rows (style + tps/tpe + ref codes)
  → prefill → KV-cache decode loop + heads.npz sampling → acoustic
  → MOSS codec decode → Float32 48 kHz → WAV file → AudioResult
```

Storage layout (app-private, SRS §38):

```
<appDocuments>/models/
  vieneu-v3-turbo-int8/        # 7 model files (exact names §4)
  codec-nano/                  # decode_full.onnx, decode_shared.data (+ meta)
  sea-g2p/sea_g2p.bin          # pronunciation dictionary
  *.part                       # in-flight downloads, removed on cancel/fail
  install-manifest.json        # local verification record (sha256 per file)
```

## 4. Download & install (FR-20, §47)

### Manifest (baked into the app, versioned with the release)

| Source | Files | Bytes |
|---|---|---|
| HF `pnnbao-ump/VieNeu-TTS-v3-Turbo` subfolder `onnx_int8/` | `config.json` 2 152 · `tokenizer.json` 22 320 · `vieneu_prefill.onnx` 1 090 823 · `vieneu_decode_step.onnx` 1 062 040 · `vieneu_acoustic_cached.onnx` 7 207 223 · `vieneu_backbone_shared.data` 103 891 968 · `vieneu_v3_heads.npz` 52 219 622 | **165 496 148** |
| HF `OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX` | `moss_audio_tokenizer_decode_full.onnx` 681 902 · `moss_audio_tokenizer_decode_shared.data` 44 198 912 · `codec_browser_onnx_meta.json` 17 036 | **44 897 848** |
| GitHub `pnnbao97/sea-g2p` release `v0.10.0` | `sea_g2p.bin` (dictionary) | **62 829 820** |
| | **Total** | **273 223 816 ≈ 273 MB** |

- Checksums: at development time resolve HF tree API (`lfs.oid` sha256 / git blob oid) and release-asset digests, bake into the manifest. Runtime: size check per file while streaming; **full sha256 verify** of every file before flipping `isInstalled`.
- Source revisions are pinned: model repo @ `61b85e3d937fbbacb387714180e8182823512523`, codec repo @ `ceff0d0749bfb3fa2d61149794ec6feef0d1e1ae`, sea-g2p release `v0.10.0`, voices JSON @ commit `2e982ff857bbe23fffa0c314e0f60da2497e2f4b`.
- Explicitly NOT downloaded (cloning out of scope): `speaker_encoder.onnx`, `denoiser.onnx`, codec `encode.*`, `model.safetensors`, gguf exports, fp32/`onnx_update` export.
- Download: `package:http` streaming to `*.part`, progress = bytes/total, cancel deletes `.part`. No resume in MVP (restart from zero; documented in UI).
- Commit ordering: write final file → verify → update `install-manifest.json` → upsert `models` row (`isInstalled=true`, `checksum`, `sizeBytes`, `license='Apache-2.0'`, `filePath`) → emit `installed`. Any failure leaves no `isInstalled` row and no stray files.
- On app start: quick presence+size audit; mismatch → `corrupt` state (never silently "installed").
- `tool/fetch_model.sh`: dev helper — reuses `assets/models/**` staging if present, else downloads from HF/GitHub into `<repo>/.cache/models/` for desktop e2e.

### Migration from the bundled-asset approach

1. Remove all `assets/models/*` entries from `pubspec.yaml`.
2. Add `assets/models/` to `.gitignore` (keep local staging; never commit 200 MB blobs).
3. Delete `ModelAssetManager` copy-from-bundle logic; `ModelInstallService` supersedes it.
4. Engine takes its model root from install state, not from `rootBundle`.

## 5. Engine port (reference → Dart)

Port target: `OnnxV3LiteEngine` in `src/vieneu/_v3_turbo_engine/onnx_runtime_lite.py` (torch-free path), plus `prompt_v3_turbo.build_prompt_2d`, `configuration_v3_turbo`, `rep_history`. Reference snapshot: `/tmp/opencode/vieneu_ref/`.

Pipeline inside the existing worker isolate (UI never blocks):

1. **Phonemize** — sea-g2p via `dart:ffi` C ABI (`sea_g2p_open` / `sea_g2p_phonemize` / `sea_g2p_string_free` / `sea_g2p_last_error` / `sea_g2p_close`, header `sea_g2p.h`). Dictionary `sea_g2p.bin` from the install dir. Same rules as the Python reference — no Dart reimplementation (sea-g2p README warns a second implementation drifts).
2. **BPE encode** — existing `VieNeuTokenizer`, `add_special_tokens=false`, verified against golden vectors from Python `tokenizers` on the same `tokenizer.json`.
3. **Prompt build (2-D rows, `n_vq+1` columns)** — per `build_prompt_2d`: `[style_token(16), text_prompt_start, …phone_ids, text_prompt_end]` rows with audio-pad fill, then ref rows `[audio_ref_slot | ref_codes…]` from the voice preset. Token ids from `onnx_int8/config.json`.
4. **Prefill** — `vieneu_prefill.onnx` once; outputs become the initial KV past.
5. **Decode loop** — `vieneu_decode_step.onnx` per token with KV-cache (`past` in/out through `OnnxTensor`); logits head = `text_emb`-tied projection from `vieneu_v3_heads.npz` (loaded once, parsed by a minimal Dart `.npz`/`.npy` reader — zip + header + raw array); sampling: temperature 0.8, top-k, top-p, repetition penalty window (`rep_history` semantics); stop at EOS/max.
6. **Acoustic** — `vieneu_acoustic_cached.onnx` over generated codes → per-frame feature rows; second head (from npz) → frame code logits; sample per the reference (acoustic frame loop) → `(T, n_vq)` codes.
7. **Codec decode** — `moss_audio_tokenizer_decode_full.onnx` + `decode_shared.data` → Float32 mono @ **48 000 Hz**.
8. **WAV write** — 16-bit PCM WAV to the synthesis-cache directory → `AudioResult(path, duration=real WAV duration, sampleRate=48000, …)`.

Speaker conditioning: real `speaker_emb` from `voices_v3_turbo.json` through `xvec_proj` (npz) exactly as `_speaker_anchor` in the reference — replacing the fake hash embeddings.

`OnnxModelHost` extensions: keep-alive multi-session map (prefill, decode_step, acoustic, codec) in one worker isolate; typed input/output tensors incl. int64 sequences and past-KV tuples; external-data `.data` resolved relative to graph path; `run` on the right session (`sessionId` param or per-session handles). Loading is lazy and `isReady` does no I/O (contract in `tts_engine.dart`).

Cancellation: engine honors the queue's generation counter — a superseded synth returns `CancelledFailure` (isolate teardown path already exists).

## 6. Voices (bundled asset)

- Source: GitHub `pnnbao97/VieNeu-TTS` → `src/vieneu/assets/voices_v3_turbo.json` (180 332 B, Apache-2.0), pinned commit in the spec's references; bundled as an app asset (small, versioned with the app).
- Shape: `{ meta, default_voice: "Hải Đăng", presets: { id → … } }` — **25 presets** (model card says 23; use the file's `count: 25`; `aliases` keep old names working). Per-voice fields consumed: display name/description, `speaker_emb`, `ref_codes`, and style/featured flags as present.
- Voice picker + default `default_voice_id` setting populate from this file; picker rows are disabled with "cần cài model" until install completes.

## 7. UI states (approved Section 2)

`Mô hình` tab replaces the 26-line placeholder with ruled rows per SRS FR-20, using the locked design language:

| State | Display | Action |
|---|---|---|
| notInstalled | name · int8 · 48 kHz · ≈ 273 MB · `Apache-2.0 · pnnbao-ump/VieNeu-TTS-v3-Turbo` | `Tải về` |
| downloading | progress bar + MB received/total | `Hủy` (drops `.part`) |
| verifying | "Đang kiểm tra…" (engine stays not-ready) | — |
| installed | `Đã cài` · actual on-disk size · license line | `Xóa` (confirm dialog names the freed size) |
| corrupt | "Model hỏng — cần tải lại" | `Tải lại` |
| error(network) | "Lỗi mạng: …", `.part` cleaned | `Thử lại` |

- `ttsEngineProvider` watches install state (swap without app restart). Read-aloud's existing `Mở Models` button routes here.
- Mid-synthesis model disappearance → `ModelUnavailableFailure` → banner + Models tab; no infinite retry.
- License line always visible on every model row (§47).

## 8. Decisions & known quirks

- **Speed** is playback-rate only (`JustAudioOutput.setSpeed` → just_audio); the engine always emits base-rate audio; `AudioResult.duration` = real WAV duration; `TtsOptions.cacheKey` untouched. (Current production behavior; no double speed application.)
- **int8 first**; fp32/`onnx_update` is a later Models-screen option, not in this cycle.
- **No resume** on interrupted downloads (MVP).
- **Bundled vs downloaded**: code (`.so`) ships in the app; every byte of model/g2p/codec data is downloaded and deletable (FR-20, store-friendly APK).
- Voice cloning, emotion cues, conversation mode, streaming frame decode: explicitly out (deferred).

## 9. Testing & verification (approved Section 3)

1. **Unit / golden (default `flutter test`, no model needed):**
   - BPE: golden encode/decode vectors generated with Python `tokenizers`.
   - npz/npy reader against `vieneu_v3_heads.npz` fixture slices; sampling determinism (seeded); prompt-row builder vs Python-produced rows.
   - sea-g2p FFI on Linux: sample sentences → phoneme strings match Python `SEAPipeline` goldens.
   - `ModelInstallService` with a fake HTTP source: progress, cancel, wrong-sha → `corrupt`, `.part` cleanup, DB row invariants; state machine transitions.
   - Widget: Models screen per state; Read Aloud → `Mở Models`; voice picker disabled state.
2. **E2E with real model (tag `model`, excluded from default run):** `tool/fetch_model.sh` (reuses local staging) → synthesize fixed sentences on **Linux desktop** → assert WAV header (RIFF/48 kHz/mono), **non-silent** samples, duration within expected range, cache hit skips re-synthesis. This is the "chạy là có model" gate: proven before any device work.
3. **Manual (post-handoff):** Android device — download on phone, listen to all presets, record RTF.

Keep the existing 387 tests green; `dart analyze lib` stays at 0 errors.

## 10. Risks & escapes

| Risk | Mitigation / escape |
|---|---|
| flutter_onnxruntime 1.23 cannot load external-data `.data` or int8 ops on some platform | Highest-priority spike in week 1 (desktop e2e first). Escape: fp32 export (no quantization, same external-data question) — report to user before promising Android if neither loads |
| Port drift vs reference (prompt/heads/sampling) → silent or garbled audio | Step-level goldens (phoneme ids → prefill outputs → first N tokens) + non-silence e2e |
| sea-g2p Android `.so` (no release asset) needs cargo-ndk | `tool/build_g2p.sh` + commit Linux prebuilt first (desktop verified); Android build when toolchain available; risk flagged, not blocking desktop delivery |
| Phone RTF slower than laptops | Sentence queue + look-ahead already hide latency; measure on device; perf tuning is Phase 6 |
| ~273 MB download on mobile | Honest size in UI before first byte; cancel anytime; per-file progress |

## 11. Out of scope (following cycles, in order)

- **B — Phase 3 PDF**: `file_picker` + PDF text extraction.
- **C — Phase 4 Extraction**: Anthropic-format prompts, reflow, vision OCR via existing `lib/ai/ocr`.
- **D — Phase 6 remainder**: full Model Manager polish (fp32 row, Nano), model search, background audio/MP3 export, perf.

## 12. References

- Model: `https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Turbo` @ `61b85e3d937fbbacb387714180e8182823512523` (subfolder `onnx_int8/`), codec: `https://huggingface.co/OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX` @ `ceff0d0749bfb3fa2d61149794ec6feef0d1e1ae`, g2p: `https://github.com/pnnbao97/sea-g2p` release `v0.10.0` (main @ `e825173f235d08ea19315b2b279fb11153b44cea`), voices: `pnnbao97/VieNeu-TTS` @ `2e982ff857bbe23fffa0c314e0f60da2497e2f4b` → `src/vieneu/assets/voices_v3_turbo.json`.
- Reference implementation snapshot: `/tmp/opencode/vieneu_ref/` (`onnx_runtime_lite.py`, `prompt_v3_turbo.py`, `configuration_v3_turbo.py`, `rep_history.py`).
- SRS: FR-09, FR-12, FR-19/20, FR-10 (speed), §27, §35, §38, §47.
- Existing seams: `lib/domain/engines/tts_engine.dart`, `lib/ai/onnx/onnx_model_host.dart`, `models` table in `lib/data/database/app_database.dart`, `ttsEngineProvider` in `lib/presentation/read_aloud/read_aloud_providers.dart:25`.

## Definition of done

1. [x] `flutter test` green (459 passing: the original 387 + engine/manifest/install-service/widget suites), `flutter analyze lib` 0 errors (49 pre-existing infos/warnings), Linux desktop build passes (`flutter build linux --debug`).
2. [x] Tagged e2e proves real, non-silent Vietnamese audio on Linux desktop with the staged int8 model: `integration_test/vieneu_model_e2e_test.dart` (tag `model`, `dart_test.yaml`-declared, 10 min timeout) — "Xin chào Việt Nam" → 48 kHz mono 16-bit WAV, 960 ms, rms 3609 / peak 22142 (reference run: rms ≈ 3480), frame count consistent with the reported duration, and a second request served from cache without re-synthesis. Run: `tool/fetch_model.sh` then `flutter test integration_test -d linux --tags model`.
3. [x] Models tab implements all six FR-20 states with a verified install, and Read Aloud synthesizes through the real engine (proven by the e2e above; on-device listening pass per §9.3 stays post-handoff). `ttsEngineProvider` swaps engine ↔ `ModelMissingTtsEngine` without an app restart.
4. [x] No model bytes in pubspec assets (only `assets/voices/voices_v3_turbo.json`); `assets/models/` gitignored; license line rendered on every model row per §47.

Machine notes (2026-09-29 session): the local Flutter SDK carries two uncommitted patches — `build_linux.dart` forces `CC=gcc/CXX=g++` (this box's clang++ cannot link libstdc++), and `native_assets/linux/native_assets.dart` gained a `/usr/bin` linker fallback (llvm-14 ships no `ld.lld`; lld not installed). Both were needed for the desktop build; a stock SDK on a normal Linux box needs neither. A killed cmake run once left a truncated ONNX Runtime tarball that re-extracted as a corrupt `.so` — delete `build/linux/x64/debug/plugins/flutter_onnxruntime/onnxruntime/` if linking ever fails with `ELF section name out of range`.
