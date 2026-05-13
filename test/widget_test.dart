import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_dash/services/score_service.dart';

void main() {
  test('ScoreService is a singleton', () {
    expect(ScoreService.instance, same(ScoreService.instance));
  });
}
