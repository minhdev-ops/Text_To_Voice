#!/usr/bin/env bash
# Builds the sea-g2p native phonemizer for Android (spec §4 / §10).
#
# Upstream publishes prebuilt libraries for linux-x86_64, macos-aarch64 and
# windows-x86_64 only, so Android needs its own build from the same pinned tag.
# This script only orchestrates; it does not install a toolchain. You need:
#
#   * rustup, with the Android targets:
#       rustup target add aarch64-linux-android armv7-linux-androideabi \
#                         x86_64-linux-android
#   * cargo-ndk:      cargo install cargo-ndk
#   * an Android NDK (ANDROID_NDK_HOME, or one under $ANDROID_HOME/ndk)
#
#   ./tool/build_g2p.sh                 # every ABI
#   ./tool/build_g2p.sh arm64-v8a       # one ABI
#
# Output: android/app/src/main/jniLibs/<abi>/libsea_g2p_rs.so
#
# The bare name matters: Android loads jniLibs libraries by name, and
# `lib/ai/tts/vieneu_phonemizer.dart` (libraryFileNames) looks for exactly
# `libsea_g2p_rs.so` on Android. The dictionary is still *downloaded* by the
# Model Manager (FR-20) — only the library ships in the APK.
set -euo pipefail
cd "$(dirname "$0")/.."

G2P_REPO="https://github.com/pnnbao97/sea-g2p"
G2P_TAG="v0.10.0"
SRC_DIR=".cache/sea-g2p"
JNI_DIR="android/app/src/main/jniLibs"
LIB="libsea_g2p_rs.so"

declare -A TRIPLE=(
  [arm64-v8a]=aarch64-linux-android
  [armeabi-v7a]=armv7-linux-androideabi
  [x86_64]=x86_64-linux-android
  [x86]=i686-linux-android
)

# arm64-v8a is the real-device ABI and is always built. The 32-bit ones exist
# for the emulator: an image running x86/x86_64 without a matching `libsea_g2p_rs.so`
# has no phonemizer at all, and the app then reports "Bộ chuyển ngữ âm tiếng Việt
# chưa có trên thiết bị này" for every sentence — which looks exactly like a
# broken model but is a missing ABI.
abis=("$@")
if (( ${#abis[@]} == 0 )); then
  abis=(arm64-v8a armeabi-v7a x86_64 x86)
fi

command -v cargo >/dev/null 2>&1 || {
  echo "cargo not found." >&2
  echo "Install Rust, then: rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android" >&2
  exit 2
}
if ! cargo ndk --version >/dev/null 2>&1; then
  echo "cargo-ndk not found. Install it with: cargo install cargo-ndk" >&2
  exit 2
fi
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "note: ANDROID_NDK_HOME is unset; cargo-ndk will look for the NDK under the Android SDK." >&2
fi

if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "==> clone $G2P_REPO @ $G2P_TAG"
  mkdir -p "$(dirname "$SRC_DIR")"
  git clone --depth 1 --branch "$G2P_TAG" "$G2P_REPO" "$SRC_DIR"
fi

for abi in "${abis[@]}"; do
  triple="${TRIPLE[$abi]:-}"
  if [[ -z "$triple" ]]; then
    echo "Unknown ABI '$abi'. Expected one of: ${!TRIPLE[*]}" >&2
    exit 2
  fi

  echo "==> $abi ($triple)"
  # `capi` instead of the default `python` feature: the C ABI drops PyO3, so the
  # library has no Python runtime to look for (see the crate's Cargo.toml).
  # Run from the crate directory: cargo-ndk runs `cargo metadata` in the current
  # directory and (as of cargo-ndk 4.1.2) ignores --manifest-path for it, so
  # passing the manifest from the project root fails. -o must then be absolute.
  mkdir -p "$JNI_DIR"
  jni_abs="$(cd "$JNI_DIR" && pwd)"
  (cd "$SRC_DIR" && cargo ndk -t "$triple" -o "$jni_abs" \
    build --release --no-default-features --features capi)

  if [[ ! -f "$JNI_DIR/$abi/$LIB" ]]; then
    echo "expected $JNI_DIR/$abi/$LIB after the build" >&2
    exit 1
  fi
done

echo
echo "Built:"
ls -l "$JNI_DIR"/*/"$LIB"
echo
echo "Rebuild the APK and the Android phonemizer becomes available; until then the"
echo "Models screen reports it as unavailable rather than failing mid-sentence."
