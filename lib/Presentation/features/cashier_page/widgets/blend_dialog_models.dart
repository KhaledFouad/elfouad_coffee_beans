part of 'blend_dialog.dart';

class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

enum InputMode { grams, price }

enum _PadTarget { grams, price, none }
