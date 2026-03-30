import 'package:flutter/material.dart';

import '../models/team_knowledge_block.dart';
import '../models/team_knowledge_page.dart';
import '../services/team_knowledge_service.dart';
import 'ticket_detail_page.dart';

class TeamKnowledgePageView extends StatefulWidget {
  final String teamId;
  final bool canManage;

  const TeamKnowledgePageView({
    super.key,
    required this.teamId,
    required this.canManage,
  });

  @override
  State<TeamKnowledgePageView> createState() => _TeamKnowledgePageViewState();
}

class _TeamKnowledgePageViewState extends State<TeamKnowledgePageView> {
  final TeamKnowledgeService _service = TeamKnowledgeService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<TeamKnowledgePage> _pages = [];
  List<TeamKnowledgeBlock> _blocks = [];
  TeamKnowledgePage? _selectedPage;
  bool _isLoading = true;
  bool _isLoadingBlocks = false;
  bool _isSaving = false;
  String? _error;
  String _selectedIcon = 'DOC';
  String _searchQuery = '';
  String _draftBaseline = '';
  int _pageLoadRequestId = 0;
  int _blockLoadRequestId = 0;

  static const List<String> _iconTokens = [
    'DOC',
    'NOTE',
    'OPS',
    'WARN',
    'LINK',
  ];

  static final List<_KnowledgeTemplate> _templates = [
    _KnowledgeTemplate(
      title: 'Takim SOP',
      summary: 'Standart operasyon adimlarini burada toplayin.',
      icon: 'DOC',
      blocks: const [
        TeamKnowledgeBlock(
          id: '',
          pageId: '',
          type: TeamKnowledgeBlockType.callout,
          title: 'Amac',
          value: 'Bu sayfa takimin ortak calisma standardini toplar.',
          checked: false,
          sortOrder: 0,
        ),
        TeamKnowledgeBlock(
          id: '',
          pageId: '',
          type: TeamKnowledgeBlockType.checklist,
          title: 'Vardiya kontrolu',
          value: 'Panel ve guvenlik kontrolunu tamamla.',
          checked: false,
          sortOrder: 1,
        ),
      ],
    ),
    _KnowledgeTemplate(
      title: 'Ariza Cozum Hafizasi',
      summary: 'Tekrarlayan arizalar icin kisa cozum notlari.',
      icon: 'OPS',
      blocks: const [
        TeamKnowledgeBlock(
          id: '',
          pageId: '',
          type: TeamKnowledgeBlockType.paragraph,
          title: 'Belirti',
          value: 'Belirti, neden ve uygulanan cozum adimlarini yazin.',
          checked: false,
          sortOrder: 0,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _loadPages();
  }

  @override
  void didUpdateWidget(covariant TeamKnowledgePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId == widget.teamId) return;

    _pageLoadRequestId++;
    _blockLoadRequestId++;
    _searchController.clear();

    setState(() {
      _pages = [];
      _blocks = [];
      _selectedPage = null;
      _selectedIcon = 'DOC';
      _titleController.clear();
      _summaryController.clear();
      _searchQuery = '';
      _draftBaseline = '';
      _error = null;
      _isLoading = true;
      _isLoadingBlocks = false;
    });

    _loadPages();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPages({String? selectPageId}) async {
    final requestId = ++_pageLoadRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pages = await _service.listPages(widget.teamId);
      TeamKnowledgePage? selected;

      if (pages.isNotEmpty) {
        selected = pages.first;
        if (selectPageId != null) {
          for (final page in pages) {
            if (page.id == selectPageId) {
              selected = page;
              break;
            }
          }
        }
      }

      if (!mounted || requestId != _pageLoadRequestId) return;
      setState(() {
        _pages = pages;
        _selectedPage = selected;
        _selectedIcon = selected?.icon ?? 'DOC';
        _titleController.text = selected?.title ?? '';
        _summaryController.text = selected?.summary ?? '';
        _isLoading = false;
        _isLoadingBlocks = selected != null;
      });

      if (selected == null) {
        setState(() {
          _blocks = [];
          _draftBaseline = '';
        });
        return;
      }

      await _loadBlocksForPage(selected, showErrorSnack: false);
    } catch (error) {
      if (!mounted || requestId != _pageLoadRequestId) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
        _isLoadingBlocks = false;
      });
    }
  }

  Future<void> _selectPage(TeamKnowledgePage page) async {
    setState(() {
      _selectedPage = page;
      _selectedIcon = page.icon;
      _titleController.text = page.title;
      _summaryController.text = page.summary;
      _blocks = [];
      _isLoadingBlocks = true;
    });

    await _loadBlocksForPage(page);
  }

  Future<void> _loadBlocksForPage(
    TeamKnowledgePage page, {
    bool showErrorSnack = true,
  }) async {
    final requestId = ++_blockLoadRequestId;

    try {
      final blocks = await _service.getBlocks(page.id);
      if (!mounted ||
          requestId != _blockLoadRequestId ||
          _selectedPage?.id != page.id) {
        return;
      }
      setState(() {
        _blocks = blocks;
        _isLoadingBlocks = false;
        _draftBaseline = _buildDraftSignature(
          title: _titleController.text,
          summary: _summaryController.text,
          icon: _selectedIcon,
          blocks: blocks,
        );
      });
    } catch (error) {
      if (!mounted ||
          requestId != _blockLoadRequestId ||
          _selectedPage?.id != page.id) {
        return;
      }
      setState(() => _isLoadingBlocks = false);
      if (showErrorSnack) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sayfa yuklenemedi: $error')));
      }
    }
  }

  Future<void> _createPage({
    required String title,
    required String summary,
    required String icon,
    List<TeamKnowledgeBlock> blocks = const [],
  }) async {
    final page = await _service.createPage(
      teamId: widget.teamId,
      title: title,
      summary: summary,
      icon: icon,
    );
    if (blocks.isNotEmpty) {
      await _service.replaceBlocks(page.id, blocks);
    }
    await _loadPages(selectPageId: page.id);
  }

  Future<void> _savePage() async {
    final page = _selectedPage;
    if (page == null || _titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _service.updatePage(
        pageId: page.id,
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        icon: _selectedIcon,
      );
      await _service.replaceBlocks(page.id, _blocks);
      await _loadPages(selectPageId: page.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilgi sayfasi kaydedildi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kaydetme hatasi: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showNewPageDialog() async {
    final canContinue = await _confirmDiscardChangesIfNeeded();
    if (!canContinue) return;

    final titleController = TextEditingController();
    final summaryController = TextEditingController();
    String icon = 'DOC';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Yeni sayfa'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: icon,
                        decoration: const InputDecoration(labelText: 'Ikon'),
                        items:
                            _iconTokens
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => icon = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Baslik'),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: summaryController,
                        decoration: const InputDecoration(labelText: 'Ozet'),
                        minLines: 2,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Iptal'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Olustur'),
                    ),
                  ],
                ),
          ),
    );

    if (confirmed != true || titleController.text.trim().isEmpty) return;
    await _createPage(
      title: titleController.text.trim(),
      summary: summaryController.text.trim(),
      icon: icon,
    );
  }

  Future<void> _showTemplateDialog() async {
    final canContinue = await _confirmDiscardChangesIfNeeded();
    if (!canContinue) return;

    final template = await showModalBottomSheet<_KnowledgeTemplate>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children:
                  _templates
                      .map(
                        (item) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(item.title),
                            subtitle: Text(item.summary),
                            onTap: () => Navigator.pop(context, item),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
    );

    if (template == null) return;
    await _createPage(
      title: template.title,
      summary: template.summary,
      icon: template.icon,
      blocks: template.blocks,
    );
  }

  Future<void> _showBlockDialog({
    TeamKnowledgeBlock? block,
    int? index,
    TeamKnowledgeBlockType? initialType,
  }) async {
    final isEdit = block != null && index != null;
    TeamKnowledgeBlockType type =
        initialType ?? block?.type ?? TeamKnowledgeBlockType.paragraph;
    final titleController = TextEditingController(text: block?.title ?? '');
    final valueController = TextEditingController(text: block?.value ?? '');
    bool checked = block?.checked ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final isLongText =
                  type == TeamKnowledgeBlockType.paragraph ||
                  type == TeamKnowledgeBlockType.callout;
              return AlertDialog(
                title: Text(isEdit ? 'Blok duzenle' : 'Yeni blok'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<TeamKnowledgeBlockType>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Tip'),
                      items:
                          TeamKnowledgeBlockType.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => type = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Baslik'),
                    ),
                    const SizedBox(height: 12),
                    if (type == TeamKnowledgeBlockType.checklist)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tamamlandi'),
                        value: checked,
                        onChanged:
                            (value) =>
                                setDialogState(() => checked = value ?? false),
                      ),
                    TextField(
                      controller: valueController,
                      decoration: InputDecoration(labelText: _valueLabel(type)),
                      minLines: isLongText ? 3 : 1,
                      maxLines: isLongText ? 5 : 1,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Iptal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Kaydet'),
                  ),
                ],
              );
            },
          ),
    );

    if (saved != true) return;

    final updated = TeamKnowledgeBlock(
      id: block?.id ?? '',
      pageId: _selectedPage?.id ?? '',
      type: type,
      title: titleController.text.trim(),
      value: valueController.text.trim(),
      checked: checked,
      sortOrder: index ?? _blocks.length,
    );

    setState(() {
      if (index != null) {
        _blocks[index] = updated;
      } else {
        _blocks = [..._blocks, updated];
      }
    });
  }

  Future<void> _deletePage() async {
    if (!widget.canManage || _selectedPage == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sayfayi sil'),
            content: const Text(
              'Bu sayfa ve tum bloklari silinecek. Emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Iptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    await _service.deletePage(_selectedPage!.id);
    await _loadPages();
  }

  void _removeBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
      _blocks =
          _blocks
              .asMap()
              .entries
              .map((entry) => entry.value.copyWith(sortOrder: entry.key))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 1120;
    final filteredPages =
        _pages.where((page) {
          if (_searchQuery.isEmpty) return true;
          return page.title.toLowerCase().contains(_searchQuery) ||
              page.summary.toLowerCase().contains(_searchQuery);
        }).toList();

    if (_isLoading && _pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _pages.isEmpty) {
      return Center(child: Text(_error!));
    }

    final sidebar = _buildSidebar(theme, filteredPages);
    final editor = _buildEditor(theme);

    return isWide
        ? Row(
          children: [
            SizedBox(width: 320, child: sidebar),
            Expanded(child: editor),
          ],
        )
        : Column(
          children: [
            SizedBox(height: 320, child: sidebar),
            Expanded(child: editor),
          ],
        );
  }

  Widget _buildSidebar(ThemeData theme, List<TeamKnowledgePage> filteredPages) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withOpacity(0.14)),
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.14)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bilgi Merkezi',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Takim SOP, rehber ve operasyon hafizasini burada tutun.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Sayfa ara',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _showNewPageDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Yeni Sayfa'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showTemplateDialog,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Sablon'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                filteredPages.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _pages.isEmpty
                              ? 'Henuz takim sayfasi yok.'
                              : 'Aramana uygun sayfa bulunamadi.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredPages.length,
                      itemBuilder: (context, index) {
                        final page = filteredPages[index];
                        final selected = _selectedPage?.id == page.id;
                        return Material(
                          color:
                              selected
                                  ? theme.colorScheme.primary.withOpacity(0.08)
                                  : Colors.transparent,
                          child: ListTile(
                            title: Text(
                              page.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              page.summary.isEmpty ? 'Ozet yok' : page.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              final canContinue =
                                  await _confirmDiscardChangesIfNeeded(
                                    targetPageId: page.id,
                                  );
                              if (!canContinue) return;
                              await _selectPage(page);
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    if (_selectedPage == null) {
      return Center(
        child: Text(
          'Bilgi Merkezi hazir. Yeni sayfa ile baslayin.',
          style: theme.textTheme.titleMedium,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: _selectedIcon,
                            underline: const SizedBox.shrink(),
                            items:
                                _iconTokens
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedIcon = value);
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                hintText: 'Sayfa basligi',
                                border: InputBorder.none,
                              ),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _savePage,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Kaydet'),
                          ),
                          if (widget.canManage) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _deletePage,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Sil'),
                            ),
                          ],
                        ],
                      ),
                      TextField(
                        controller: _summaryController,
                        decoration: const InputDecoration(
                          labelText: 'Sayfa ozeti',
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    TeamKnowledgeBlockType.values
                        .map(
                          (type) => OutlinedButton.icon(
                            onPressed:
                                () => _showBlockDialog(initialType: type),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(type.label),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 20),
              if (_isLoadingBlocks)
                const Center(child: CircularProgressIndicator())
              else if (_blocks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Bu sayfada henuz blok yok.',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(
                    _blocks.length,
                    (index) => _buildBlockCard(theme, _blocks[index], index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildDraftSignature({
    required String title,
    required String summary,
    required String icon,
    required List<TeamKnowledgeBlock> blocks,
  }) {
    final normalizedBlocks = blocks
        .map(
          (block) =>
              '${block.type.dbValue}|${block.title}|${block.value}|${block.checked}|${block.sortOrder}',
        )
        .join('||');
    return '${title.trim()}###${summary.trim()}###$icon###$normalizedBlocks';
  }

  bool _hasUnsavedChanges() {
    if (_selectedPage == null) return false;
    return _buildDraftSignature(
          title: _titleController.text,
          summary: _summaryController.text,
          icon: _selectedIcon,
          blocks: _blocks,
        ) !=
        _draftBaseline;
  }

  Future<bool> _confirmDiscardChangesIfNeeded({String? targetPageId}) async {
    if (!_hasUnsavedChanges()) return true;
    if (targetPageId != null && _selectedPage?.id == targetPageId) {
      return true;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kaydedilmemis degisiklikler var'),
            content: const Text(
              'Bu sayfada kaydedilmemis degisiklikler var. Devam edersen mevcut duzenlemeler kaybolacak.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Kal ve kaydet'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Devam et'),
              ),
            ],
          ),
    );

    return discard == true;
  }

  Widget _buildBlockCard(ThemeData theme, TeamKnowledgeBlock block, int index) {
    final canOpenTicket =
        block.type == TeamKnowledgeBlockType.ticketLink &&
        block.value.trim().isNotEmpty;
    final subtitle = _blockSubtitle(block);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading:
            block.type == TeamKnowledgeBlockType.checklist
                ? Checkbox(value: block.checked, onChanged: null)
                : CircleAvatar(child: Text(block.type.label.substring(0, 1))),
        title: Text(block.title.isEmpty ? block.type.label : block.title),
        subtitle: Text(subtitle, maxLines: 4, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canOpenTicket)
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => TicketDetailPage(ticketId: block.value.trim()),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            IconButton(
              onPressed: () => _showBlockDialog(block: block, index: index),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => _removeBlock(index),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }

  static String _valueLabel(TeamKnowledgeBlockType type) {
    switch (type) {
      case TeamKnowledgeBlockType.paragraph:
        return 'Icerik';
      case TeamKnowledgeBlockType.checklist:
        return 'Kontrol notu';
      case TeamKnowledgeBlockType.callout:
        return 'Uyari metni';
      case TeamKnowledgeBlockType.ticketLink:
        return 'Is emri ID';
      case TeamKnowledgeBlockType.cardLink:
        return 'Kart referansi';
    }
  }

  static String _blockSubtitle(TeamKnowledgeBlock block) {
    switch (block.type) {
      case TeamKnowledgeBlockType.checklist:
        final status = block.checked ? 'Tamamlandi' : 'Bekliyor';
        if (block.value.isEmpty) {
          return status;
        }
        return '$status - ${block.value}';
      case TeamKnowledgeBlockType.ticketLink:
        return block.value.isEmpty
            ? 'Bagli is emri ID eklenmedi.'
            : 'Bagli is emri ID: ${block.value}';
      case TeamKnowledgeBlockType.cardLink:
        return block.value.isEmpty
            ? 'Bagli kart referansi eklenmedi.'
            : 'Bagli kart referansi: ${block.value}';
      case TeamKnowledgeBlockType.callout:
      case TeamKnowledgeBlockType.paragraph:
        return block.value.isEmpty ? 'Icerik yok' : block.value;
    }
  }
}

class _KnowledgeTemplate {
  final String title;
  final String summary;
  final String icon;
  final List<TeamKnowledgeBlock> blocks;

  const _KnowledgeTemplate({
    required this.title,
    required this.summary,
    required this.icon,
    required this.blocks,
  });
}
