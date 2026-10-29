import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/epg_programme.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_selector_sheet.dart';
import '../widgets/channel_avatar.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({
    super.key,
    required this.channels,
    required this.programmes,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onWatch,
  });

  final List<Channel> channels;
  final List<EpgProgramme> programmes;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<Channel> onWatch;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _categoryService = const CategoryService();
  final _searchController = TextEditingController();
  Map<String, List<EpgProgramme>> _byChannel = const {};
  late CategoryFilter _selectedFilter = _categoryService.buildAllFilter(widget.channels.length);
  List<CategoryFilter> _genreFilters = const [];
  List<CategoryFilter> _countryFilters = const [];
  List<CategoryFilter> _rawGroupFilters = const [];

  @override
  void initState() {
    super.initState();
    _initCategories();
    _indexProgrammes();
    _searchController.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant GuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.programmes != widget.programmes) _indexProgrammes();
    if (oldWidget.channels != widget.channels) _initCategories();
  }

  void _initCategories() {
    final counts = _categoryService.countGroups(widget.channels);
    _genreFilters = _categoryService.buildGenreFilters(counts);
    _countryFilters = _categoryService.buildCountryFilters(counts);
    _rawGroupFilters = _categoryService.buildRawGroupFilters(counts);
    _selectedFilter = _categoryService.buildAllFilter(widget.channels.length);
  }

  void _indexProgrammes() {
    final index = <String, List<EpgProgramme>>{};
    for (final programme in widget.programmes) {
      final id = programme.channelId;
      index.putIfAbsent(id, () => []).add(programme);

      final cleanId = id.replaceAll(RegExp(r'@[A-Za-z0-9]+$'), '');
      if (cleanId != id) {
        index.putIfAbsent(cleanId, () => []).add(programme);
      }
      index.putIfAbsent(id.toLowerCase(), () => []).add(programme);

      final normalized = _normalizeName(id);
      if (normalized.isNotEmpty) {
        index.putIfAbsent('norm:$normalized', () => []).add(programme);
      }
    }
    _byChannel = index;
  }

  List<EpgProgramme> _getProgrammesForChannel(Channel channel) {
    if (channel.id != null && channel.id!.isNotEmpty) {
      if (_byChannel.containsKey(channel.id)) {
        return _byChannel[channel.id]!;
      }
      final cleanId = channel.id!.replaceAll(RegExp(r'@[A-Za-z0-9]+$'), '');
      if (_byChannel.containsKey(cleanId)) {
        return _byChannel[cleanId]!;
      }
      final lower = channel.id!.toLowerCase();
      if (_byChannel.containsKey(lower)) {
        return _byChannel[lower]!;
      }
    }
    final normName = _normalizeName(channel.name);
    if (normName.isNotEmpty && _byChannel.containsKey('norm:$normName')) {
      return _byChannel['norm:$normName']!;
    }
    return const <EpgProgramme>[];
  }

  static String _normalizeName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\.id$'), '')
        .replaceAll(RegExp(r'\.tv$'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<Channel> get _visibleChannels {
    final query = _searchController.text.trim().toLowerCase();
    return widget.channels
        .where((channel) {
          final matchesFilter = _selectedFilter.matches(channel);
          final matchesQuery =
              query.isEmpty ||
              channel.name.toLowerCase().contains(query) ||
              channel.group.toLowerCase().contains(query) ||
              (channel.id?.toLowerCase().contains(query) ?? false);
          return matchesFilter && matchesQuery;
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 600 &&
            constraints.maxWidth > constraints.maxHeight;
        final allFilter = _categoryService.buildAllFilter(widget.channels.length);
        final quickFilters = _categoryService.buildQuickFilters(
          widget.channels.length,
          _genreFilters,
          _countryFilters,
        );

        final displayPills = <CategoryFilter>[...quickFilters];
        if (!displayPills.any((f) => f.id == _selectedFilter.id) &&
            _selectedFilter.type != CategoryType.all) {
          displayPills.insert(1, _selectedFilter);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search guide channels, genres, or countries...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _refresh();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: _selectedFilter.type != CategoryType.all
                        ? AppColors.accent
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => CategorySelectorSheet.show(
                        context,
                        selectedFilter: _selectedFilter,
                        allFilter: allFilter,
                        genreFilters: _genreFilters,
                        countryFilters: _countryFilters,
                        rawGroupFilters: _rawGroupFilters,
                        onSelect: (filter) => setState(() => _selectedFilter = filter),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune,
                              size: 20,
                              color: _selectedFilter.type != CategoryType.all
                                  ? const Color(0xFF07110F)
                                  : Colors.white,
                            ),
                            if (wide || _selectedFilter.type != CategoryType.all) ...[
                              const SizedBox(width: 6),
                              Text(
                                _selectedFilter.type != CategoryType.all
                                    ? _selectedFilter.label
                                    : 'Categories',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _selectedFilter.type != CategoryType.all
                                      ? const Color(0xFF07110F)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20),
                scrollDirection: Axis.horizontal,
                children: [
                  ...displayPills.map((filter) {
                    final isSelected = _selectedFilter.id == filter.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Text(filter.icon, style: const TextStyle(fontSize: 13)),
                        label: Text('${filter.label} (${filter.count})'),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.grid_view_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      label: Text(
                        'All Categories (${_genreFilters.length + _countryFilters.length})',
                      ),
                      onPressed: () => CategorySelectorSheet.show(
                        context,
                        selectedFilter: _selectedFilter,
                        allFilter: allFilter,
                        genreFilters: _genreFilters,
                        countryFilters: _countryFilters,
                        rawGroupFilters: _rawGroupFilters,
                        onSelect: (filter) => setState(() => _selectedFilter = filter),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 36 : 20,
                8,
                wide ? 36 : 20,
                8,
              ),
              child: Text(
                widget.loading
                    ? 'Loading schedule…'
                    : '${_visibleChannels.length} channels · local times',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
            Expanded(child: _buildContent(context, wide)),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, bool wide) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null && widget.programmes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                'Guide unavailable',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final channels = _visibleChannels;
    if (channels.isEmpty) {
      return const Center(child: Text('No channels match this filter.'));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(wide ? 36 : 20, 4, wide ? 36 : 20, 24),
      itemCount: channels.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final channel = channels[index];
        final entries = _getProgrammesForChannel(channel);
        final now = DateTime.now().toUtc();
        final current = _firstWhere(
          entries,
          (programme) =>
              !programme.start.isAfter(now) && programme.stop.isAfter(now),
        );
        final next = _firstWhere(
          entries,
          (programme) => programme.start.isAfter(now),
        );
        return _GuideRow(
          channel: channel,
          current: current,
          next: next,
          wide: wide,
          autofocus: index == 0,
          onWatch: () => widget.onWatch(channel),
        );
      },
    );
  }

  EpgProgramme? _firstWhere(
    List<EpgProgramme> items,
    bool Function(EpgProgramme) test,
  ) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

class _GuideRow extends StatefulWidget {
  const _GuideRow({
    required this.channel,
    required this.current,
    required this.next,
    required this.wide,
    required this.autofocus,
    required this.onWatch,
  });

  final Channel channel;
  final EpgProgramme? current;
  final EpgProgramme? next;
  final bool wide;
  final bool autofocus;
  final VoidCallback onWatch;

  @override
  State<_GuideRow> createState() => _GuideRowState();
}

class _GuideRowState extends State<_GuideRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final duration = widget.current?.stop.difference(widget.current!.start);
    final elapsed = widget.current == null
        ? 0
        : now.difference(widget.current!.start).inMilliseconds;
    final progress = duration == null || duration.inMilliseconds <= 0
        ? 0.0
        : (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);

    return AnimatedScale(
      scale: _focused ? 1.015 : 1,
      duration: const Duration(milliseconds: 120),
      child: Card(
        color: _focused ? AppColors.elevated : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _focused ? AppColors.accent : AppColors.divider,
            width: _focused ? 2 : 1,
          ),
        ),
        child: InkWell(
          autofocus: widget.autofocus,
          onFocusChange: (value) => setState(() => _focused = value),
          onTap: widget.onWatch,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: widget.wide
                ? _buildWide(context, progress)
                : _buildCompact(context, progress),
          ),
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context, double progress) {
    return SizedBox(
      height: 112,
      child: Row(
        children: [
          SizedBox(width: 220, child: _channelIdentity(context)),
          const SizedBox(width: 12),
          Expanded(
            child: _programmeCard(
              context,
              'NOW',
              widget.current,
              progress: progress,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _programmeCard(context, 'NEXT', widget.next)),
          const SizedBox(width: 12),
          const Icon(
            Icons.play_circle_outline,
            color: AppColors.accent,
            size: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _channelIdentity(context)),
            const Icon(Icons.play_circle_outline, color: AppColors.accent),
          ],
        ),
        const SizedBox(height: 12),
        _programmeCard(context, 'NOW', widget.current, progress: progress),
        const SizedBox(height: 8),
        _programmeCard(context, 'NEXT', widget.next),
      ],
    );
  }

  Widget _channelIdentity(BuildContext context) {
    return Row(
      children: [
        ChannelAvatar(
          channel: widget.channel,
          width: 52,
          height: 52,
          borderRadius: BorderRadius.circular(10),
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                widget.channel.group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _programmeCard(
    BuildContext context,
    String label,
    EpgProgramme? programme, {
    double progress = 0,
  }) {
    final title =
        programme?.title ??
        (label == 'NOW' ? 'Schedule unavailable' : 'No upcoming listing');
    final time = programme == null
        ? ''
        : '${_formatTime(context, programme.start)} – ${_formatTime(context, programme.stop)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              if (time.isNotEmpty)
                Expanded(
                  child: Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (label == 'NOW' && programme != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.divider,
                color: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime dateTime) {
    final local = dateTime.toLocal();
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  }
}
