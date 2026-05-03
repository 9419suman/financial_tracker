import '../models/user_profile.dart';

class PasswordCandidateService {
  // Generates ordered list of password candidates to try when the email
  // has no explicit instruction — most likely to least likely.
  static List<String> generate(UserProfile profile) {
    final parts = profile.fullName.trim().split(' ');
    final first = parts.first.toLowerCase();
    final first4 = first.length >= 4 ? first.substring(0, 4) : first;
    final pan = profile.pan.toUpperCase();
    final pan5 = pan.length >= 5 ? pan.substring(0, 5) : pan;
    final phone = profile.phone;
    final phone4 = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
    final card4 = profile.cardLast4;
    final dd = profile.dd;
    final mm = profile.mm;
    final yyyy = profile.yyyy;
    final yy = profile.yy;

    final candidates = <String>[];

    // name + dob combos
    for (final npart in [first4, first, first4.toUpperCase(), first.toUpperCase()]) {
      for (final dpart in ['$dd$mm', '$dd$mm$yyyy', '$dd$mm$yy', yyyy, '$mm$yyyy']) {
        candidates.add('$npart$dpart');
      }
    }

    // dob + card last 4 (SBI Cashback style: ddmmyyyy + last4)
    if (card4.isNotEmpty) {
      candidates.addAll(['$dd$mm$yyyy$card4', '$dd$mm$yy$card4', card4]);
    }

    // dob only
    candidates.addAll(['$dd$mm$yyyy', '$dd$mm$yy', '$dd$mm', '$yyyy$mm$dd', '$mm$dd$yyyy']);

    // phone combos
    if (phone.isNotEmpty) {
      candidates.addAll([
        phone,
        phone4,
        '${first4.toUpperCase()}$phone4',
        '$first4$phone4',
        '$phone$dd$mm',
      ]);
    }

    // PAN combos
    candidates.addAll([
      '${pan5.toLowerCase()}$dd$mm',
      '$pan5$dd$mm',
      '${pan5.toLowerCase()}$dd$mm$yyyy',
      '$pan$dd$mm',
    ]);

    // name only variants
    candidates.addAll([
      first, first.toUpperCase(), first4, first4.toUpperCase(),
      parts.join('').toLowerCase(), parts.join('').toUpperCase(),
    ]);

    // all known customer IDs (try every bank's known password)
    candidates.addAll(profile.bankPasswords.values);

    // deduplicate, preserve order, skip empty strings
    final seen = <String>{};
    return candidates.where((c) => c.isNotEmpty && seen.add(c)).toList();
  }
}
