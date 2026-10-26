/// The studio (home) screen — full port of the web viewHome:
/// topbar (badge + back-step + language + theme | 🎧 contact), signout row,
/// brand hero, empty-state hero, items/papers tabs with counts, item cards
/// (chip, thumb, dims, metaline, copies stepper min 1, ✏️ e🗑️), the
/// choose/document/edit sheets with the exact field defaults (8.5×5.4,
/// presets هوية/جواز, copies 1, SAME_PAGE checked), per-sheet 💾 save on the
/// paper preview (300 DPI), and the three export actions with the web word
/// flow: warm cache → OS share sheet → download fallback.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_model.dart';
import 'model.dart';
import 'render.dart';
import 'shared.dart';
import 'theme.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, required this.model});

  final AppModel model;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  int _tab = 0;
  bool _exportBusy = false;

  AppModel get m => widget.model;

  void _switchTab(int index) {
    setState(() {
      _tab = index == 0 ? 0 : 1;
    });
    if (index == 1) m.warmDocx();
  }

  void _contact() =>
      showContactSheet(context, locale: m.locale, dark: m.dark);

  // The web back-step badge button: closes a sheet or goes back from the
  // paper tab to the items tab (no-op when the items tab is already shown).
  void _backStep() {
    if (_tab == 1) _switchTab(0);
  }

  Future<void> _addPhotos() async {
    final files = await m.picker.pickMultiImage();
    if (files.isEmpty) return;
    await m.addPhotoFiles(files);
  }

  // ------------------------------------------------------------------
  // sheets
  // ------------------------------------------------------------------
  void _openChoose() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SheetShell(
        title: m.t('chooseType'),
        dark: m.dark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChooseOption(
              icon: '📷',
              title: m.t('photoType'),
              body: m.t('photoBody'),
              dark: m.dark,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _addPhotos();
              },
            ),
            _ChooseOption(
              icon: '🪪',
              title: m.t('docType'),
              body: m.t('docBody'),
              dark: m.dark,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openDocSheet();
              },
            ),
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: m.dark ? PMColors.darkFrame : PMColors.frame),
                ),
                child: Text(m.t('cancel')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDocSheet() {
    final m0 = m;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _DocSheet(model: m0),
      ),
    );
  }

  void _openEdit(int index) {
    final m0 = m;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _EditSheet(model: m0, index: index),
      ),
    );
  }

  // ------------------------------------------------------------------
  // export actions (webapp flows verbatim)
  // ------------------------------------------------------------------
  Future<void> _shareDocx() async {
    if (m.items.isEmpty) {
      showToast(context, m.t('addItemsFirst'), icon: '⚠️');
      return;
    }
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      // Only enforces a busy state while the file still needs building.
      if (!m.docxWarm) showToast(context, m.t('preparing'), icon: '⏳');
      final payload = await m.getDocxPayload();
      final outcome = await m.tryNativeFileShare(payload);
      if (!mounted) return;
      if (outcome == 'shared') {
        showToast(context, m.t('shared'), icon: '📲');
      } else if (outcome != 'cancelled') {
        await m.saveOutFile(payload.name, payload.bytes);
        if (mounted) {
          showToast(context, m.t('downloadFallback'), icon: '📥');
        }
      }
    } catch (error) {
      if (mounted) {
        showToast(
          context,
          '${m.t('errorPrefix')}$error',
          icon: '⚠️',
        );
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _downloadDocx() async {
    if (m.items.isEmpty) {
      showToast(context, m.t('addItemsFirst'), icon: '⚠️');
      return;
    }
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final payload = await m.getDocxPayload();
      await m.saveOutFile(payload.name, payload.bytes);
      if (mounted) showToast(context, m.t('downloaded'), icon: '📥');
    } catch (error) {
      if (mounted) {
        showToast(context, '${m.t('errorPrefix')}$error', icon: '⚠️');
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _saveImages() async {
    if (m.items.isEmpty) {
      showToast(context, m.t('addItemsFirst'), icon: '⚠️');
      return;
    }
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final plan = m.plan;
      for (var p = 0; p < plan.totalPages; p++) {
        final bytes = await renderPagePng(m.plan, p, 300);
        await m.saveOutFile('PhotoMagic_A4_Page${p + 1}.png', bytes);
      }
      if (mounted) showToast(context, m.t('downloaded'), icon: '💾');
    } catch (error) {
      if (mounted) {
        showToast(context, '${m.t('errorPrefix')}$error', icon: '⚠️');
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _savePage(int pageIndex) async {
    try {
      final bytes = await renderPagePng(m.plan, pageIndex, 300);
      await m.saveOutFile('PhotoMagic_A4_Page${pageIndex + 1}.png', bytes);
      if (mounted) showToast(context, m.t('downloaded'), icon: '📥');
    } catch (error) {
      if (mounted) {
        showToast(context, '${m.t('errorPrefix')}$error', icon: '⚠️');
      }
    }
  }

  // ------------------------------------------------------------------
  // build
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final scheme = m.dark ? const Scheme.dark() : const Scheme();
    final plan = m.plan;
    final box = BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.frame),
      boxShadow: [m.dark ? pmShadowDark : pmShadow],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TopBar(
                locale: m.locale,
                dark: m.dark,
                onLocale: (v) => m.applyLocale(v),
                onTheme: (v) => m.applyTheme(v),
                onContact: _contact,
                onBack: _backStep,
                backLabel: '←',
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: m.logout,
                  icon: const Text('⏏', style: TextStyle(fontSize: 13)),
                  label: Text(
                    m.t('logout'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: scheme.dim,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: scheme.frame),
                    foregroundColor: scheme.dim,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                Image.asset(
                  'assets/branding/app_logo.png',
                  height: 84,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(height: 8),
                Text(
                  m.t('appTitle'),
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: scheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  m.t('taglineShort'),
                  style: TextStyle(fontSize: 12, color: scheme.dim),
                ),
              ],
            ),
            if (m.items.isEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: box,
                  child: Column(
                    children: [
                      const Text('🖼️',
                          style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 10),
                      Text(
                        m.t('emptyTitle'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.t('emptyBody'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: scheme.dim,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 260,
                        height: 44,
                        child: FilledButton(
                          onPressed: _openChoose,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '+',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.accentInk,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                m.t('addItem'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.accentInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.glass,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabBtn(
                        label:
                            '${m.t('tabItems')} (${m.items.length})',
                        active: _tab == 0,
                        dark: m.dark,
                        onTap: () => _switchTab(0),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _TabBtn(
                        label: '${m.t('tabPapers')} (${plan.totalPages})',
                        active: _tab == 1,
                        dark: m.dark,
                        onTap: () => _switchTab(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _tab == 0 ? _buildItems(box) : _buildPapers(scheme, plan, box),
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

  Widget _buildItems(BoxDecoration box) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
      children: [
        if (m.items.isNotEmpty)
          Center(
            child: SizedBox(
              width: 260,
              height: 44,
              child: FilledButton(
                onPressed: _openChoose,
                child: Text(
                  '+  ${m.t('addItem')}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: m.dark ? PMColors.darkAccentInk : PMColors.accentInk,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        for (var i = 0; i < m.items.length; i++) _itemCard(i, box),
      ],
    );
  }

  Widget _itemCard(int index, BoxDecoration box) {
    final item = m.items[index];
    final scheme = m.dark ? const Scheme.dark() : const Scheme();
    final isDoc = item.isDoc;
    final metaline = isDoc
        ? (item.duplexMode == 'BACK_SIDE' ? m.t('backSide') : m.t('samePage'))
        : (item.widthCm <= 3.05 ? m.t('photoBody') : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: box,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.glass,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDoc ? m.t('docChip') : m.t('photoChip'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: m.t('editItemTitle'),
                visualDensity: VisualDensity.compact,
                onPressed: () => _openEdit(index),
                icon: Text('✏️', style: TextStyle(fontSize: 16, color: scheme.accent)),
              ),
              IconButton(
                tooltip: m.t('delete'),
                visualDensity: VisualDensity.compact,
                onPressed: () => m.deleteItem(index),
                icon: Text('🗑️', style: TextStyle(fontSize: 16, color: scheme.alarm)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RawImage(
                  image: item.bitmap,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.widthCm} × ${item.heightCm}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: scheme.text,
                      ),
                    ),
                    if (metaline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        metaline,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.dim,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _stepper(index, scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepper(int index, Scheme scheme) {
    final item = m.items[index];
    Widget button(String label, int delta) {
      return GestureDetector(
        onTap: () => m.stepCopies(index, delta),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.frame, width: 1.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: scheme.text),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.glass,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            m.t('copiesLabel'),
            style: TextStyle(fontSize: 10.5, color: scheme.dim),
          ),
          button('－', -1),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 26),
            child: Text(
              '${item.copies}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.text,
              ),
            ),
          ),
          button('＋', 1),
        ],
      ),
    );
  }

  Widget _buildPapers(Scheme scheme, Plan plan, BoxDecoration box) {
    if (m.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: box,
            child: Column(
              children: [
                const Text('📄', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 10),
                Text(
                  m.t('emptyTitle'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: scheme.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
      children: [
        for (var p = 0; p < plan.totalPages; p++) _paperCard(p, plan, box),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            onPressed: _exportBusy ? null : _shareDocx,
            child: Text(
              m.t('exportShare'),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: m.dark ? PMColors.darkAccentInk : PMColors.accentInk,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            onPressed: _exportBusy ? null : _downloadDocx,
            style: OutlinedButton.styleFrom(side: BorderSide(color: scheme.frame)),
            child: Text(
              m.t('exportDownload'),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: scheme.text,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            onPressed: _exportBusy ? null : _saveImages,
            style: OutlinedButton.styleFrom(side: BorderSide(color: scheme.frame)),
            child: Text(
              m.t('saveImages'),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: scheme.text,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          m.t('pagesInfo'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: scheme.dim),
        ),
        const SizedBox(height: 3),
        Text(
          m.t('margins'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: scheme.dim),
        ),
      ],
    );
  }

  Widget _paperCard(int p, Plan plan, BoxDecoration box) {
    final scheme = m.dark ? const Scheme.dark() : const Scheme();
    final faces = plan.placed.where((e) => e.page == p).toList();
    final hasBack = faces.any((e) => e.back);
    final hasFront = faces.any((e) => !e.back);
    final caption = '${m.t('sheet')} ${p + 1} ${m.t('of')} ${plan.totalPages}'
        ' (${hasBack && !hasFront ? m.t('backSheet') : m.t('frontSheet')})';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: box,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _savePage(p),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: scheme.accent),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  '💾 ${m.t('saveThisSheet')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scheme.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 210 / 297,
              child: CustomPaint(
                painter: PagePreviewPainter(
                  plan: plan,
                  pageIndex: p,
                  dark: m.dark,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two-slot tab bar row (items / papers).
class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = dark ? const Scheme.dark() : const Scheme();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? scheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: active ? scheme.accentInk : scheme.dim,
          ),
        ),
      ),
    );
  }
}

/// One choice row of the choose-type sheet.
class _ChooseOption extends StatelessWidget {
  const _ChooseOption({
    required this.icon,
    required this.title,
    required this.body,
    required this.dark,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String body;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = dark ? const Scheme.dark() : const Scheme();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.glass,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: scheme.dim,
                        ),
                      ),
                    ],
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

/// The document sheet — same structure/defaults as the web docSheet:
/// front/back pickers with live previews, duplex radio (SAME_PAGE default),
/// 8.5×5.4 defaults, هوية/جواز presets, copies (default 1).
class _DocSheet extends StatefulWidget {
  const _DocSheet({required this.model});

  final AppModel model;

  @override
  State<_DocSheet> createState() => _DocSheetState();
}

class _DocSheetState extends State<_DocSheet> {
  final _w = TextEditingController(text: '8.5');
  final _h = TextEditingController(text: '5.4');
  final _copies = TextEditingController(text: '1');
  String _duplex = 'SAME_PAGE';

  AppModel get m => widget.model;

  @override
  void initState() {
    super.initState();
    m.addListener(_rebuild);
  }

  @override
  void dispose() {
    m.removeListener(_rebuild);
    _w.dispose();
    _h.dispose();
    _copies.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _applyPreset(double w, double h) {
    setState(() {
      _w.text = '$w';
      _h.text = '$h';
    });
  }

  Future<void> _add() async {
    if (m.docFrontBitmap == null) {
      showToast(context, m.t('addPhotoFirst'), icon: '⚠️');
      return;
    }
    final w = double.tryParse(_w.text.trim().replaceAll(',', '.')) ?? 8.5;
    final h = double.tryParse(_h.text.trim().replaceAll(',', '.')) ?? 5.4;
    final copies = int.tryParse(_copies.text.trim()) ?? 1;
    final ok = await m.addDoc(
        _duplex, w, h, copies < 1 ? 1 : copies);
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = m.dark ? const Scheme.dark() : const Scheme();
    final headingStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      color: scheme.dim,
    );
    final fieldStyle = TextStyle(fontSize: 14, color: scheme.text);

    Widget radio(String value, String label) {
      return RadioListTile<String>(
        value: value,
        groupValue: _duplex,
        onChanged: (v) => setState(() => _duplex = v ?? 'SAME_PAGE'),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: scheme.text,
          ),
        ),
        activeColor: scheme.accent,
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.zero,
      );
    }

    return SheetShell(
      title: m.t('docTitle'),
      dark: m.dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _FacePick(
                  image: m.docFrontBitmap,
                  icon: '📸',
                  label: m.t('frontFace'),
                  dark: m.dark,
                  onTap: () => m.pickDocFront(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FacePick(
                  image: m.docBackBitmap,
                  icon: '🔄',
                  label: m.t('backFace'),
                  dark: m.dark,
                  onTap: () => m.pickDocBack(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(m.t('placement'), style: headingStyle),
          radio('SAME_PAGE', m.t('samePage')),
          radio('BACK_SIDE', m.t('backSide')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.t('widthCm'), style: headingStyle),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _w,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: fieldStyle,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.t('heightCm'), style: headingStyle),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _h,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: fieldStyle,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _applyPreset(8.5, 5.4),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: scheme.frame),
                  minimumSize: const Size(0, 34),
                ),
                child: Text(
                  'هوية 8.5×5.4',
                  style: TextStyle(fontSize: 11.5, color: scheme.dim),
                ),
              ),
              OutlinedButton(
                onPressed: () => _applyPreset(12.5, 8.8),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: scheme.frame),
                  minimumSize: const Size(0, 34),
                ),
                child: Text(
                  'جواز 12.5×8.8',
                  style: TextStyle(fontSize: 11.5, color: scheme.dim),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(m.t('copies'), style: headingStyle),
          const SizedBox(height: 4),
          TextField(
            controller: _copies,
            keyboardType: const TextInputType.numberWithOptions(),
            style: fieldStyle,
            decoration: const InputDecoration(isDense: true),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: scheme.frame),
                    ),
                    child: Text(
                      m.t('cancel'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: scheme.dim,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _add,
                    child: Text(
                      m.t('add'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: scheme.accentInk,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One face picker box of the document sheet (dash-look border + emoji when
/// empty, cover-cropped live preview + caption once picked).
class _FacePick extends StatelessWidget {
  const _FacePick({
    required this.image,
    required this.icon,
    required this.label,
    required this.dark,
    required this.onTap,
  });

  final ui.Image? image;
  final String icon;
  final String label;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = dark ? const Scheme.dark() : const Scheme();
    final picked = image != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.glass,
          border: Border.all(
            color: picked ? scheme.accent : scheme.frame,
            width: picked ? 1.6 : 1.2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: picked
            ? Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(image: image, fit: BoxFit.cover),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.surface.withAlpha(230),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: scheme.text,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.dim,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// The edit sheet — exact web fields: width / height / (doc only) duplex
/// radio / copies, with the same validation toast on bad input.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.model, required this.index});

  final AppModel model;
  final int index;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _w;
  late final TextEditingController _h;
  late final TextEditingController _copies;
  String _duplex = 'SAME_PAGE';

  AppModel get m => widget.model;

  PmItem? get _item =>
      widget.index >= 0 && widget.index < m.items.length
          ? m.items[widget.index]
          : null;

  @override
  void initState() {
    super.initState();
    final item = _item;
    _w = TextEditingController(text: '${item?.widthCm ?? 3}');
    _h = TextEditingController(text: '${item?.heightCm ?? 4}');
    _copies =
        TextEditingController(text: '${item?.copies ?? 1}');
    _duplex = item?.duplexMode == 'BACK_SIDE' ? 'BACK_SIDE' : 'SAME_PAGE';
    m.addListener(_rebuild);
  }

  @override
  void dispose() {
    m.removeListener(_rebuild);
    _w.dispose();
    _h.dispose();
    _copies.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final item = _item;
    if (item == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final w = double.tryParse(_w.text.trim().replaceAll(',', '.')) ?? 0;
    final h = double.tryParse(_h.text.trim().replaceAll(',', '.')) ?? 0;
    final copies = int.tryParse(_copies.text.trim()) ?? 0;
    if (w < 1 || h < 1 || copies < 1) {
      showToast(
        context,
        '${m.t('errorPrefix')}${m.t('invalidDimensions')}',
        icon: '⚠️',
      );
      return;
    }
    m.saveEdits(
      widget.index,
      w,
      h,
      copies,
      item.isDoc ? _duplex : null,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null) return const SizedBox.shrink();
    final scheme = m.dark ? const Scheme.dark() : const Scheme();
    final headingStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      color: scheme.dim,
    );
    final fieldStyle = TextStyle(fontSize: 14, color: scheme.text);

    return SheetShell(
      title: m.t('editItemTitle'),
      dark: m.dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.t('widthCm'), style: headingStyle),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _w,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: fieldStyle,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.t('heightCm'), style: headingStyle),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _h,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: fieldStyle,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.isDoc) ...[
            const SizedBox(height: 10),
            Text(m.t('placement'), style: headingStyle),
            RadioListTile<String>(
              value: 'SAME_PAGE',
              groupValue: _duplex,
              onChanged: (v) => setState(() => _duplex = v ?? 'SAME_PAGE'),
              title: Text(
                m.t('samePage'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.text,
                ),
              ),
              activeColor: scheme.accent,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<String>(
              value: 'BACK_SIDE',
              groupValue: _duplex,
              onChanged: (v) => setState(() => _duplex = v ?? 'SAME_PAGE'),
              title: Text(
                m.t('backSide'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.text,
                ),
              ),
              activeColor: scheme.accent,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 10),
          Text(m.t('copies'), style: headingStyle),
          const SizedBox(height: 4),
          TextField(
            controller: _copies,
            keyboardType: const TextInputType.numberWithOptions(),
            style: fieldStyle,
            decoration: const InputDecoration(isDense: true),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: scheme.frame),
                    ),
                    child: Text(
                      m.t('cancel'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: scheme.dim,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(
                      m.t('saveEdit'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: scheme.accentInk,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
