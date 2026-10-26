/// Login + Create-account screens — ported from the web viewLogin /
/// viewCreate with the exact same contract: attempt lockout (5 → 30 s and
/// doubling), secure/offline pre-checks in browsers, suspension / expiry /
/// failure messages, and the "create account" contact channels.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'app_model.dart';
import 'auth.dart';
import 'install_bridge.dart';
import 'shared.dart';
import 'theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.model});

  final AppModel model;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _lockMsg = false; // _error currently carries the live countdown
  int _lockSeconds = 0;
  Timer? _ticker;

  AppModel get m => widget.model;

  @override
  void initState() {
    super.initState();
    _refreshLock();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Mirrors the web's live lock countdown message (Try again in {s}s).
  void _refreshLock() {
    final until = m.lockUntilMillis();
    final remain = until - DateTime.now().millisecondsSinceEpoch;
    final secs = remain > 0 ? (remain / 1000).ceil() : 0;
    if (secs <= 0) {
      _ticker?.cancel();
      _ticker = null;
      if (_lockMsg) {
        _lockMsg = false;
        if (mounted && _error != null) setState(() => _error = null);
      }
      return;
    }
    _ticker ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshLock(),
    );
    if (mounted) {
      setState(() {
        _lockSeconds = secs;
        _lockMsg = true;
        _error = m.tf('lockedOut', s: '$secs');
      });
    }
  }

  Future<void> _goCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => CreateScreen(model: m)),
    );
  }

  void _contact() =>
      showContactSheet(context, locale: m.locale, dark: m.dark);

  Future<void> _submit() async {
    if (_busy) return;
    if (_lockSeconds > 0) {
      _refreshLock();
      return;
    }
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = m.t('loginFailed'));
      return;
    }
    // Browser-only pre-checks, exactly the order of attemptLogin ().
    if (pmIsWebBrowser) {
      if (!pmIsSecureContext()) {
        setState(() => _error = m.t('secureRequired'));
        return;
      }
      if (!pmIsOnline()) {
        setState(() => _error = m.t('loginOffline'));
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await verifyAccount(username, password);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result.status) {
      case VerifyStatus.success:
        m.clearLock();
        _password.clear();
        // The node KEY is the identity: save the normalized typed name.
        m.saveSession(username.toLowerCase());
        m.startMonitor();
        // The root swaps the home widget automatically.
      case VerifyStatus.expired:
        setState(() => _error = m.t('accountExpired'));
      case VerifyStatus.suspended:
        setState(() => _error = m.t('accountSuspended'));
      case VerifyStatus.offline:
        setState(() => _error = m.t('serverError'));
      case VerifyStatus.invalid:
        m.registerFailure();
        _refreshLock();
        if (mounted) {
          setState(() {
            if (_lockSeconds == 0) _error = m.t('loginFailed');
            // otherwise _refreshLock already posted the countdown message.
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = m.dark ? const Scheme.dark() : const Scheme();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: TopBar(
                locale: m.locale,
                dark: m.dark,
                onLocale: (v) => m.applyLocale(v),
                onTheme: (v) => m.applyTheme(v),
                onContact: _contact,
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.frame),
                        boxShadow: [
                          m.dark ? pmShadowDark : pmShadow,
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/icons/icon-192.png',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            m.t('loginTitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: scheme.text,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _username,
                            textInputAction: TextInputAction.next,
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(color: scheme.text),
                            decoration: InputDecoration(
                              labelText: m.t('username'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            onSubmitted: (_) => _submit(),
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(color: scheme.text),
                            decoration: InputDecoration(
                              labelText: m.t('password'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: scheme.accentInk,
                                      ),
                                    )
                                  : Text(
                                      m.t('loginButton'),
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: scheme.accentInk,
                                      ),
                                    ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.alarm.withAlpha(26),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.alarm,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _goCreate,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: scheme.accent),
                              ),
                              child: Text(
                                m.t('createAccount'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InstallBanner(locale: m.locale, dark: m.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, required this.model});

  final AppModel model;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  AppModel get m => widget.model;

  @override
  void initState() {
    super.initState();
    // Pushed route — refresh on model changes (locale/theme flips happen
    // through this screen's own top bar).
    m.addListener(_rebuild);
  }

  @override
  void dispose() {
    m.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _contact() =>
      showContactSheet(context, locale: m.locale, dark: m.dark);

  @override
  Widget build(BuildContext context) {
    final scheme = m.dark ? const Scheme.dark() : const Scheme();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: TopBar(
                locale: m.locale,
                dark: m.dark,
                onLocale: (v) => m.applyLocale(v),
                onTheme: (v) => m.applyTheme(v),
                onContact: _contact,
                onBack: () => Navigator.of(context).maybePop(),
                backLabel: m.locale == 'ar' ? '→' : '←',
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.frame),
                        boxShadow: [
                          m.dark ? pmShadowDark : pmShadow,
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.t('createAccountTitle'),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: scheme.text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            m.t('createAccountMessage'),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.9,
                              color: scheme.dim,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ChannelTile(
                            color: PMColors.whatsapp,
                            asset: 'assets/icons/ic_whatsapp.svg',
                            label: m.t('contactWhatsapp'),
                            url: ContactCh.whatsapp,
                          ),
                          ChannelTile(
                            color: PMColors.telegram,
                            asset: 'assets/icons/ic_telegram.svg',
                            label: m.t('contactTelegram'),
                            url: ContactCh.telegram,
                          ),
                          ChannelTile(
                            color: PMColors.email,
                            asset: 'assets/icons/ic_email.svg',
                            label: m.t('contactEmail'),
                            url: ContactCh.email,
                          ),
                          ChannelTile(
                            color: PMColors.telegram,
                            asset: 'assets/icons/ic_telegram.svg',
                            label: m.t('contactChannel'),
                            url: ContactCh.channel,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                              child: Text(
                                m.t('ok'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.accentInk,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InstallBanner(locale: m.locale, dark: m.dark),
            ),
          ],
        ),
      ),
    );
  }
}
