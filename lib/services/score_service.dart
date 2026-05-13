import 'package:shared_preferences/shared_preferences.dart';

class ScoreService {
  static final ScoreService instance = ScoreService._();
  ScoreService._();

  static const String _key = 'high_score';

  Future<int> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  Future<bool> submitScore(int score) async {
    final current = await getHighScore();
    if (score > current) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, score);
      return true;
    }
    return false;
  }
}
