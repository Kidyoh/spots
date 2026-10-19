import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'brand_mark.dart';

/// Avatar button in the header; opens [showAccountSheet].
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    return Tooltip(
      message: user == null ? 'Sign in' : 'Account',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showAccountSheet(context),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: user == null ? Palette.card : Palette.green,
            border: Border.all(color: Palette.line),
            image: user?.avatarUrl != null
                ? DecorationImage(image: NetworkImage(user!.avatarUrl!), fit: BoxFit.cover)
                : null,
          ),
          alignment: Alignment.center,
          child: user == null
              ? const Icon(Icons.person_outline_rounded, color: Palette.ink, size: 22)
              : user.avatarUrl == null
              ? Text(
                  user.initial,
                  style: const TextStyle(color: Palette.bg, fontWeight: FontWeight.w700, fontSize: 16),
                )
              : null,
        ),
      ),
    );
  }
}

/// Sign in / account sheet. [reason] explains why we're asking (e.g. the
/// user tried to save a spot while signed out).
Future<void> showAccountSheet(BuildContext context, {String? reason}) {
  return showModalBottomSheet<void>(
    context: context,
    // sized to its content (not capped at 9/16 of the screen) and scrollable,
    // so Delete account still fits on short phones
    isScrollControlled: true,
    builder: (context) {
      final state = AppScope.of(context);
      final user = state.user;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 58),
              const SizedBox(height: 14),
              Text(
                user == null ? 'Keep your own log' : 'Hi, ${user.displayName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                user == null
                    ? (reason ??
                          'Sign in to save spots to "Want to go", mark places you\'ve been, '
                              'and rate them — it follows you to the website too.')
                    : user.email ??
                          (state.backend.isLive
                              ? 'Signed in with Google'
                              : 'Demo mode · your lists stay on this phone'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              if (user == null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      state.signIn();
                    },
                    icon: const _GoogleG(),
                    label: const Text('Continue with Google', style: TextStyle(fontSize: 15.5)),
                  ),
                )
              else ...[
                Row(
                  children: [
                    _Stat(value: state.savedIds.length, label: 'want to go'),
                    const SizedBox(width: 12),
                    _Stat(value: state.visits.length, label: 'been'),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      state.signOut();
                    },
                    child: const Text('Sign out'),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: state.deletingAccount ? null : () => _confirmDeleteAccount(context),
                  style: TextButton.styleFrom(foregroundColor: Palette.danger),
                  child: state.deletingAccount
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Palette.danger),
                        )
                      : const Text('Delete account'),
                ),
              ],
              if (!state.backend.isLive) ...[
                const SizedBox(height: 14),
                const Text(
                  'Running on demo data — pass SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to go live.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Palette.muted),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Confirm, then delete the account and close the sheet. The sheet stays up
/// (with a spinner) while the request runs; the result arrives as a toast.
Future<void> _confirmDeleteAccount(BuildContext sheetContext) async {
  final state = AppScope.read(sheetContext);
  final confirmed = await showDialog<bool>(
    context: sheetContext,
    builder: (context) => DeleteAccountDialog(live: state.backend.isLive),
  );
  if (confirmed != true) return;
  await state.deleteAccount();
  if (sheetContext.mounted) Navigator.pop(sheetContext);
}

/// Spells out what deleting the account removes before anything happens.
class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key, required this.live});

  /// Live accounts lose server data; demo mode only has the phone's lists.
  final bool live;

  @override
  Widget build(BuildContext context) {
    const bullet = TextStyle(fontSize: 14, height: 1.35, color: Palette.inkSoft);
    Widget item(String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: bullet),
          Expanded(child: Text(text, style: bullet)),
        ],
      ),
    );
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: live
              ? [
                  const Text('This permanently deletes your Spots account and everything tied to it:', style: bullet),
                  item('your Want to go list'),
                  item('the places you\'ve been, with their ratings and notes — they also come off the community list'),
                  item('your profile name and photo'),
                  item('people matching on the website: your opt-in, likes and blocks'),
                  item('feedback you\'ve sent'),
                  const SizedBox(height: 12),
                  const Text(
                    'Anonymous usage stats stay, no longer tied to your account. Your Google account isn\'t affected. '
                    'This can\'t be undone.',
                    style: bullet,
                  ),
                ]
              : [
                  const Text(
                    'Demo mode: this clears your Want to go list and the places you\'ve been, with their ratings '
                    'and notes, from this phone. This can\'t be undone.',
                    style: bullet,
                  ),
                ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Palette.danger, foregroundColor: Palette.bg),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: Palette.lineSoft),
        ),
        child: Column(
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Palette.green)),
            Text(label, style: const TextStyle(fontSize: 12.5, color: Palette.muted)),
          ],
        ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(color: Palette.card, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700, fontSize: 14, height: 1),
      ),
    );
  }
}
