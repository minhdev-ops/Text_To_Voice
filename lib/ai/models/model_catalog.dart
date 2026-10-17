import 'model_descriptor.dart';
import 'matcha_vietnamese_manifest.dart';
import 'matcha_vietnamese_fp16_manifest.dart';
import 'vieneu_model_manifest.dart';

/// Catalog of all downloadable models.
class ModelCatalog {
  ModelCatalog._();

  static final List<ModelDescriptor> all = <ModelDescriptor>[
    VieNeuModelManifest() as ModelDescriptor,
    MatchaVietnameseManifest(),
    MatchaVietnameseFp16Manifest(),
  ];

  static ModelDescriptor? byId(String id) {
    for (final d in all) {
      if (d.modelId == id) return d;
    }
    return null;
  }
}
