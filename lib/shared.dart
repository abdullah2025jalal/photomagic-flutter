/// Shared widgets for every screen, ported from the web build markup:
/// - TopBar   (badge + language seg + theme on one side, "Contact me" on the
///             other — the row is LTR-independent of the active direction)
/// - contact sheet (the exact 4 channels with the verbatim brand SVG paths,
///             tinted per channel)
/// - install rectangle (browser-only via the `web/index.html` JS bridge; it
///             shows on every screen while the app runs in a browser and
///             disappears once installed / standalone)
/// - the shared glass sheet shell + toast helper
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_model.dart' show kInstallDismissKey;
import 'i18n.dart';
import 'install_bridge.dart';
import 'theme.dart';

/// Same four channels, same order, same destinations as the web build.
class ContactCh {
  ContactCh._();

  static const whatsapp = 'https://wa.me/qr/ZBCM2HUUDBTWB1';
  static const telegram = 'https://t.me/Abdullah2001jalal';
  static const channel = 'https://t.me/AbodyCode';
  static const email = 'mailto:abdullah2001jalal@gmail.com';
}

/// One channel row of the contact sheet (brand-colored border + glyph).
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.color,
    required this.asset,
    required this.label,
    required this.url,
  });

  final Color color;
  final String asset;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final uri = Uri.parse(url);
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: color.withAlpha(150), width: 1.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  asset,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  '›',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color.withAlpha(170),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass sheet shell — the direct analogue of the web `.sheet` container.
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.title,
    required this.child,
    required this.dark,
  });

  final String title;
  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = dark ? const Scheme.dark() : const Scheme();
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: scheme.frame),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.text,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Text('✕',
                      style: TextStyle(fontSize: 15, color: scheme.dim)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

void showContactSheet(
  BuildContext context, {
  required String locale,
  required bool dark,
}) {
  final sheet = SheetShell(
    title: tOf(locale, 'contactMe'),
    dark: dark,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChannelTile(
          color: PMColors.whatsapp,
          asset: 'assets/icons/ic_whatsapp.svg',
          label: tOf(locale, 'contactWhatsapp'),
          url: ContactCh.whatsapp,
        ),
        ChannelTile(
          color: PMColors.telegram,
          asset: 'assets/icons/ic_telegram.svg',
          label: tOf(locale, 'contactTelegram'),
          url: ContactCh.telegram,
        ),
        ChannelTile(
          color: PMColors.email,
          asset: 'assets/icons/ic_email.svg',
          label: tOf(locale, 'contactEmail'),
          url: ContactCh.email,
        ),
        ChannelTile(
          color: PMColors.telegram,
          asset: 'assets/icons/ic_telegram.svg',
          label: tOf(locale, 'contactChannel'),
          url: ContactCh.channel,
        ),
      ],
    ),
  );
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => sheet,
  );
}

/// Bottom-center pill, identical wording/behavior to the web toast
/// (4.5 s, bold, inverted surface/text colors — carried by the app theme).
void showToast(
  BuildContext context,
  String message, {
  String icon = '✅',
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text('$icon  $message'),
      duration: const Duration(milliseconds: 4500),
    ),
  );
}

/// The fixed top bar. The badge / language segment / theme button cluster is
/// pinned to the leading side and "Contact me" to the trailing side — the
/// same composition on every screen regardless of the active direction.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.locale,
    required this.dark,
    required this.onLocale,
    required this.onTheme,
    required this.onContact,
    this.onBack,
    this.backLabel,
  });

  final String locale;
  final bool dark;
  final void Function(String locale) onLocale;
  final void Function(bool dark) onTheme;
  final VoidCallback onContact;
  final VoidCallback? onBack;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          if (onBack != null) ...[
            _IconBtn(label: backLabel ?? '←', onTap: onBack!),
            const SizedBox(width: 8),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icons/icon-192.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          _LangSeg(locale: locale, onChanged: onLocale),
          const SizedBox(width: 8),
          _IconBtn(
            label: dark ? '☀️' : '🌙',
            onTap: () => onTheme(!dark),
          ),
          const Spacer(),
          _ContactButton(label: tOf(locale, 'contactMe'), onTap: onContact),
        ],
      ),
    );
  }
}

/// Language segment (EN | ع), exact two-slot look of the web `.seg`.
class _LangSeg extends StatelessWidget {
  const _LangSeg({required this.locale, required this.onChanged});

  final String locale;
  final void Function(String locale) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.of(context).platformBrightness ==
        Brightness.dark;
    final scheme = dark ? const Scheme.dark() : const Scheme();

    Widget slot(String label, bool on, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? scheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? scheme.accentInk : scheme.dim,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.glass,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          slot('EN', locale == 'en', () => onChanged('en')),
          const SizedBox(width: 2),
          slot('ع', locale == 'ar', () => onChanged('ar')),
        ],
      ),
    );
  }
}

/// Small outlined square button (theme / back arrows).
class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.of(context).platformBrightness ==
        Brightness.dark;
    final scheme = dark ? const Scheme.dark() : const Scheme();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.frame, width: 1.2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

/// The 🎧 outline pill — trailing side of every top bar.
class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.of(context).platformBrightness ==
        Brightness.dark;
    final scheme = dark ? const Scheme.dark() : const Scheme();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.accent, width: 1.2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎧', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: scheme.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Install rectangle — browser-only, appears on every screen (same rule as
/// the web build), disappears once installed/standalone, and dismisses
/// permanently through the shared preference key (webapp parity).
class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key, required this.locale, required this.dark});

  final String locale;
  final bool dark;

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!pmIsWebBrowser) return;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(kInstallDismissKey) == '1';
    final standalone = pmStandalone() || pmInstalled();
    final isIos = pmIsIos();
    var hasPrompt = pmInstallAvailable();
    final showIt = !dismissed && !standalone && (hasPrompt || isIos);
    if (mounted) setState(() => _visible = showIt);
    if (!showIt) return;
    // beforeinstallprompt can arrive after first paint (desktop/Android) —
    // poll briefly, exactly the "late rectangle" behavior of the web build.
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || !_visible) return;
      if (pmStandalone() || pmInstalled()) {
        if (mounted) setState(() => _visible = false);
        return;
      }
      if (!hasPrompt && pmInstallAvailable()) {
        hasPrompt = true;
        if (mounted) setState(() => _visible = true);
      }
    }
  }

  Future<void> _later() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kInstallDismissKey, '1');
    if (mounted) setState(() => _visible = false);
  }

  Future<void> _install() async {
    if (pmPromptInstall()) return;
    if (!mounted) return;
    final isIos = pmIsIos();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SheetShell(
        title: tOf(widget.locale, 'installAppTitle'),
        dark: widget.dark,
        child: Text(
          isIos
              ? tOf(widget.locale, 'installHelpIos')
              : tOf(widget.locale, 'installHelpBrowser'),
          style: TextStyle(
            fontSize: 14,
            height: 1.8,
            color: widget.dark ? PMColors.darkDim : PMColors.dim,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!pmIsWebBrowser || !_visible) return const SizedBox.shrink();
    final scheme = widget.dark ? const Scheme.dark() : const Scheme();
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.accent, width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icons/icon-192.png',
              width: 46,
              height: 46,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tOf(widget.locale, 'installAppTitle'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: scheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tOf(widget.locale, 'installAppBody'),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: scheme.dim,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _install,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(
              tOf(widget.locale, 'installAppNow'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: scheme.accentInk,
              ),
            ),
          ),
          GestureDetector(
            onTap: _later,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text('✕', style: TextStyle(fontSize: 15, color: scheme.dim)),
            ),
          ),
        ],
      ),
    );
  }
}
