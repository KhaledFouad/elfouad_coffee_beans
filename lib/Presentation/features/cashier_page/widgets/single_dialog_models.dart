part of 'single_dialog.dart';

class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

enum CalcMode { byGrams, byMoney }

enum _PadTarget { grams, money, none }
