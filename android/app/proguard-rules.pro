# Required by flutter_onnxruntime (its setup notes state this explicitly for
# Android): the plugin reaches ONNX Runtime's Java classes reflectively, so R8
# would otherwise strip them in a release build and the model would fail to load
# only on release — the worst place to find out.
#
# Verify with a release build: `flutter build apk --release`.
-keep class ai.onnxruntime.** { *; }

# google_mlkit_text_recognition exposes a language selector that names every
# recognizer ML Kit ships, but the Android artifact we depend on bundles *Latin*
# only. R8 therefore sees references to the Chinese/Devanagari/Japanese/Korean
# option classes and fails the release build (`minifyReleaseWithR8` → "Missing
# classes detected") rather than treating them as warnings — this is the release
# build failing on a code path the app never takes (we ask for Latin).
#
# The rules below are exactly the ones the Android Gradle Plugin writes to
# `build/app/outputs/mapping/release/missing_rules.txt` after a failed run; they
# suppress the check without adding any of those recognizers to the APK.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
