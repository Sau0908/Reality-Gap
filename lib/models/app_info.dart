class AppInfo {
  final String packageName;
  final String displayName;
  final String emoji;

  const AppInfo({
    required this.packageName,
    required this.displayName,
    required this.emoji,
  });

  // Curated list of common time-sink apps
  static const List<AppInfo> catalogue = [
    AppInfo(
        packageName: 'com.google.android.youtube',
        displayName: 'YouTube',
        emoji: '▶️'),
    AppInfo(
        packageName: 'com.instagram.android',
        displayName: 'Instagram',
        emoji: '📸'),
    AppInfo(
        packageName: 'com.reddit.frontpage',
        displayName: 'Reddit',
        emoji: '👾'),
    AppInfo(
        packageName: 'com.snapchat.android',
        displayName: 'Snapchat',
        emoji: '👻'),
    AppInfo(
        packageName: 'org.telegram.messenger',
        displayName: 'Telegram',
        emoji: '✈️'),
    AppInfo(packageName: 'com.whatsapp', displayName: 'WhatsApp', emoji: '💬'),
    AppInfo(
        packageName: 'com.zhiliaoapp.musically',
        displayName: 'TikTok',
        emoji: '🎵'),
    AppInfo(
        packageName: 'com.twitter.android',
        displayName: 'X (Twitter)',
        emoji: '🐦'),
    AppInfo(
        packageName: 'com.facebook.katana',
        displayName: 'Facebook',
        emoji: '👍'),
    AppInfo(
        packageName: 'com.linkedin.android',
        displayName: 'LinkedIn',
        emoji: '💼'),
    AppInfo(
        packageName: 'com.pinterest', displayName: 'Pinterest', emoji: '📌'),
    AppInfo(packageName: 'com.tumblr', displayName: 'Tumblr', emoji: '📝'),
  ];

  static AppInfo? fromPackage(String packageName) {
    try {
      return catalogue.firstWhere((a) => a.packageName == packageName);
    } catch (_) {
      return null;
    }
  }
}
