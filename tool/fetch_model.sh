#!/usr/bin/env bash
# Materialise the VieNeu-TTS v3 Turbo checkpoint for the desktop end-to-end run.
#
#   ./tool/fetch_model.sh            # fetch what is missing, then verify
#   ./tool/fetch_model.sh --verify   # verify only, no network
#
# Not shipped, not run in CI. It stages ~273 MB into `assets/models/` —
# gitignored, and the same tree `tool/reference/vieneu_reference.py` reads and the
# `model`-tagged integration test points at. Re-running is cheap: a file that is
# already staged at the right digest is left alone.
#
# Only what the engine actually reads is fetched. The cloning files
# (`speaker_encoder.onnx`, codec `encode.*`) are deliberately not (spec §4:
# cloning is out of scope).
#
# The digests below are the ones baked into
# `lib/ai/models/vieneu_model_manifest.dart`. If you bump a pinned revision,
# change both places and re-check every hash: a wrong hash fails a perfectly good
# download forever.
set -euo pipefail
cd "$(dirname "$0")/.."

STAGING="assets/models"
MODEL_DIR="$STAGING/vieneu_v3_turbo_int8"
CODEC_DIR="$STAGING/moss_audio_tokenizer_nano"
G2P_DIR="$STAGING/sea_g2p"

MODEL_BASE="https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Turbo/resolve/61b85e3d937fbbacb387714180e8182823512523/onnx_int8"
CODEC_BASE="https://huggingface.co/OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX/resolve/ceff0d0749bfb3fa2d61149794ec6feef0d1e1ae"
G2P_BASE="https://github.com/pnnbao97/sea-g2p/releases/download/v0.10.0"

command -v curl >/dev/null 2>&1 || {
  echo "curl is required." >&2
  exit 2
}
if command -v sha256sum >/dev/null 2>&1; then
  sha_of() { sha256sum "$1" | cut -d' ' -f1; }
else
  sha_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

declare -a FILES=()
add() { FILES+=("$1|$2|$3"); }

# ── backbone + heads (pnnbao-ump/VieNeu-TTS-v3-Turbo @ pinned revision) ───────
add "$MODEL_DIR/config.json" "$MODEL_BASE/config.json" \
  a9f8d9c4b4736448ab355d1a98cfe48f5e39aecf2916c37b0806c228612e9a2d
add "$MODEL_DIR/tokenizer.json" "$MODEL_BASE/tokenizer.json" \
  6cc6bcbe380b8c37bd9f2514e37c5dfa3e00e122c6e3125dae5c4afe48e39158
add "$MODEL_DIR/vieneu_prefill.onnx" "$MODEL_BASE/vieneu_prefill.onnx" \
  c6a80dabf67c820de798f8deb7d4e0f37d81b5d76e33fbe20ab5a67f2d371f4e
add "$MODEL_DIR/vieneu_decode_step.onnx" "$MODEL_BASE/vieneu_decode_step.onnx" \
  2c5b30bd8ccb751c58d651f44c074df10c4113efd08719adaa8e3dec6a6ce2ca
add "$MODEL_DIR/vieneu_acoustic_cached.onnx" "$MODEL_BASE/vieneu_acoustic_cached.onnx" \
  f631e3387c788c3d8b9a5ac5df94952af5bc4c4d1049ff8a751e76a246fff2d4
add "$MODEL_DIR/vieneu_backbone_shared.data" "$MODEL_BASE/vieneu_backbone_shared.data" \
  bb683925f7c8d826fadca4f8a0252ae4d5fc5b7837c14f6857e18f4c6666588d
add "$MODEL_DIR/vieneu_v3_heads.npz" "$MODEL_BASE/vieneu_v3_heads.npz" \
  fb22484baa424bbb775133a6e5f0d00d6299b2b256fbe3312a864b85b9aed01e

# ── codec (OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX @ pinned revision) ────
add "$CODEC_DIR/moss_audio_tokenizer_decode_full.onnx" \
  "$CODEC_BASE/moss_audio_tokenizer_decode_full.onnx" \
  0fbbafe3fd4afa2a019af5c5ced204af6e2d1db044fa40f021525d2aee95b4ac
add "$CODEC_DIR/moss_audio_tokenizer_decode_shared.data" \
  "$CODEC_BASE/moss_audio_tokenizer_decode_shared.data" \
  e69d52e0f4e84ca27850557ee54face46632d3a5a16c89bd246c7c408466dcad

# ── phonemizer (pnnbao97/sea-g2p release v0.10.0): dictionary + host library ──
add "$G2P_DIR/sea_g2p.bin" "$G2P_BASE/sea_g2p.bin" \
  4346e690d0711ebc5231e7a42c5c88aaf6e40377e894b4617c018fd81c6f4096
case "$(uname -s)" in
  Linux)
    add "$G2P_DIR/libsea_g2p_rs-linux-x86_64.so" \
      "$G2P_BASE/libsea_g2p_rs-linux-x86_64.so" \
      1db713489f688fe3e8b5b52d975853cf7d837834c9ee94c2b5bfb0ff665d0707
    ;;
  Darwin)
    add "$G2P_DIR/libsea_g2p_rs-macos-aarch64.dylib" \
      "$G2P_BASE/libsea_g2p_rs-macos-aarch64.dylib" \
      e73a497541047add91a025419dc098acf64aa1565b3ab27c73ddd81a580d0ed4
    ;;
  MINGW*|MSYS*|CYGWIN*)
    add "$G2P_DIR/sea_g2p_rs-windows-x86_64.dll" \
      "$G2P_BASE/sea_g2p_rs-windows-x86_64.dll" \
      1daff10cf65304daa56d90814f4f6a54cf6269bf22a684b940a3d7c0bbea25c3
    ;;
  *)
    echo "Unsupported host $(uname -s): sea-g2p publishes no library for it." >&2
    exit 2
    ;;
esac

verify_one() {
  local path="$1" want="$2" got
  if [[ ! -f "$path" ]]; then
    echo "MISSING $path" >&2
    return 1
  fi
  got="$(sha_of "$path")"
  if [[ "$got" != "$want" ]]; then
    echo "BAD     $path" >&2
    echo "        expected $want" >&2
    echo "        actual   $got" >&2
    return 1
  fi
  echo "ok      $path"
}

fetch_one() {
  local path="$1" url="$2" want="$3"
  if [[ -f "$path" && "$(sha_of "$path")" == "$want" ]]; then
    echo "have    $path"
    return 0
  fi
  echo "fetch   $path"
  mkdir -p "$(dirname "$path")"
  # --http1.1: an HTTP/2 stream from HuggingFace truncated a 52 MB file on an
  # earlier run, and the mismatch looked like a bad upstream file.
  curl -fL --http1.1 --retry 3 --retry-delay 2 -o "$path.part" "$url"
  mv -f "$path.part" "$path"
}

verify_only=false
if [[ "${1:-}" == "--verify" ]]; then verify_only=true; fi

status=0
for entry in "${FILES[@]}"; do
  IFS='|' read -r path url want <<<"$entry"
  if [[ "$verify_only" == true ]]; then
    verify_one "$path" "$want" || status=1
    continue
  fi
  fetch_one "$path" "$url" "$want"
  verify_one "$path" "$want" || status=1
done

if (( status != 0 )); then
  echo >&2
  echo "Verification failed. Remove the offending file and re-run:" >&2
  echo "  rm -f <path> && ./tool/fetch_model.sh" >&2
  exit 1
fi

echo
echo "Model staged in $STAGING/."
echo "Run the tagged end-to-end on Linux desktop:"
echo "  flutter test integration_test/vieneu_model_e2e_test.dart -d linux --tags model"
