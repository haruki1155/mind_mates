import '../domain/mind_aid_dataset_models.dart';
import 'mind_aid_engine.dart';

class MindAidDatasetEngine {
  static final MindAidEngine _engine = MindAidEngine();

  static String getResponse(String input, MindAidDatasetBundle dataset) {
    return _engine.process(input, dataset).response;
  }
}
