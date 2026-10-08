import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

class SaveService {
  SaveService(this._prefs);

  static const _key = 'buildhell_save_v1';

  final SharedPreferences _prefs;

  static Future<SaveService> create() async =>
      SaveService(await SharedPreferences.getInstance());

  /// 저장된 진행이 있으면 [state]에 불러온다. 손상된 데이터는 무시한다.
  bool loadInto(GameState state) {
    final raw = _prefs.getString(_key);
    if (raw == null) return false;
    try {
      state.loadJson(jsonDecode(raw) as Map<String, dynamic>);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> save(GameState state) =>
      _prefs.setString(_key, jsonEncode(state.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}
