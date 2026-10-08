import 'dart:math' as math;

/// 한국식 큰 수 단위 (만 단위로 4자리씩 끊는다).
const List<String> _units = [
  '',
  '만',
  '억',
  '조',
  '경',
  '해',
  '자',
  '양',
  '구',
  '간',
  '정',
  '재',
  '극',
];

/// 숫자를 "12.34억" 같은 형태로 보여준다.
///
/// 게임 화면에서 "살 수 있을 것 같은데 못 사는" 착시가 없도록 반올림이 아니라
/// 내림으로 자른다.
String formatNumber(double value) {
  if (value.isNaN) return '0';
  if (value.isInfinite) return '∞';
  if (value < 0) return '-${formatNumber(-value)}';

  if (value < 10000) {
    if (value < 100 && value != value.floorToDouble()) {
      return ((value * 10).floor() / 10).toStringAsFixed(1);
    }
    return value.floor().toString();
  }

  var exp = (math.log(value) / math.ln10 / 4).floor();
  var mantissa = value / math.pow(10000.0, exp);
  // 부동소수점 오차 보정
  if (mantissa >= 10000) {
    exp += 1;
    mantissa /= 10000;
  } else if (mantissa < 1) {
    exp -= 1;
    mantissa *= 10000;
  }

  if (exp >= _units.length) {
    var e = (math.log(value) / math.ln10).floor();
    var m = value / math.pow(10.0, e);
    if (m >= 10) {
      e += 1;
      m /= 10;
    } else if (m < 1) {
      e -= 1;
      m *= 10;
    }
    return '${((m * 100).floor() / 100).toStringAsFixed(2)}e$e';
  }

  final String digits;
  if (mantissa < 10) {
    digits = ((mantissa * 100).floor() / 100).toStringAsFixed(2);
  } else if (mantissa < 100) {
    digits = ((mantissa * 10).floor() / 10).toStringAsFixed(1);
  } else {
    digits = mantissa.floor().toString();
  }
  return '$digits${_units[exp]}';
}

/// 초를 "3시간 12분" 형태로.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h시간 $m분';
  if (m > 0) return '$m분 $s초';
  return '$s초';
}
