/// Names of pages that one feature opens in another. Features never import
/// each other (see ARCHITECTURE.md); they navigate by these names instead,
/// and `app/` maps each name to its page.
abstract final class AppRoutes {
  /// Set a master password. Pops with a confirmation message, or null if
  /// the user went back without setting one.
  static const setMasterPassword = '/security/set-password';

  /// A page opened from the menu (Security, Themes, Backup, Settings):
  /// the app locking leaves it open (Round 24), it shows nothing of a
  /// section.
  static const menuPage = '/menu';

  /// The Notifications page (Round 31), also opened from Medicine.
  static const notifications = '/notifications';
}
