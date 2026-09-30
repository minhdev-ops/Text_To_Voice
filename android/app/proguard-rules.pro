# Required by flutter_onnxruntime (its setup notes state this explicitly for
# Android): the plugin reaches ONNX Runtime's Java classes reflectively, so R8
# would otherwise strip them in a release build and the model would fail to load
# only on release — the worst place to find out.
#
# Verify with a release build: `flutter build apk --release`.
-keep class ai.onnxruntime.** { *; }
