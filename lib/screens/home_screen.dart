import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/epg_programme.dart';
import '../services/category_service.dart';
import '../services/epg_service.dart';
import '../services/playlist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_selector_sheet.dart';
import '../widgets/channel_avatar.dart';
import 'guide_screen.dart';
import 'player_screen.dart';

enum _AppSection { live, guide, favorites }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _playlistService = PlaylistService();
  final _epgService = EpgService();
  final _categoryService = const CategoryService();
  final _searchController = TextEditingController();
  List<Channel> _channels = const [];
  List<EpgProgramme> _programmes = const [];
  Set<String> _favorites = {};
  late CategoryFilter _selectedFilter = _categoryService.buildAllFilter(0);
  List<CategoryFilter> _genreFilters = const [];
  List<CategoryFilter> _countryFilters = const [];
  List<CategoryFilter> _rawGroupFilters = const [];
  _AppSection _section = _AppSection.live;
  bool _loadingPlaylist = true;
  bool _loadingEpg = false;
  String? _playlistError;
  String? _epgError;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadPlaylist();
    _searchController.addListener(_refresh);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _favorites = prefs.getStringList('favorites')?.toSet() ?? {},
      );
    }
  }

  Future<void> _loadPlaylist({bool forceRemote = false}) async {
    setState(() {
      _loadingPlaylist = true;
      _playlistError = null;
    });
    try {
      final channels = await _playlistService.fetchChannels(
        preferAsset: !forceRemote,
      );
      if (!mounted) return;
      final counts = _categoryService.countGroups(channels);
      final genres = _categoryService.buildGenreFilters(counts);
      final countries = _categoryService.buildCountryFilters(counts);
      final raw = _categoryService.buildRawGroupFilters(counts);
      final all = _categoryService.buildAllFilter(channels.length);
      setState(() {
        _channels = channels;
        _loadingPlaylist = false;
        _genreFilters = genres;
        _countryFilters = countries;
        _rawGroupFilters = raw;
        _selectedFilter = all;
      });
      if (_section == _AppSection.guide && _programmes.isEmpty) _loadEpg();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _playlistError = error.toString();
        _loadingPlaylist = false;
      });
    }
  }

  Future<void> _loadEpg() async {
    setState(() {
      _loadingEpg = true;
      _epgError = null;
    });
    try {
      final programmes = await _epgService.fetchCombinedProgrammes();
      if (!mounted) return;
      setState(() {
        _programmes = programmes;
        _loadingEpg = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _epgError = error.toString();
        _loadingEpg = false;
      });
    }
  }

  List<Channel> _visibleChannels({required bool favoritesOnly}) {
    final query = _searchController.text.trim().toLowerCase();
    return _channels
        .where((channel) {
          final matchesFilter = _selectedFilter.matches(channel);
          final matchesFavorite =
              !favoritesOnly || _favorites.contains(channel.url);
          final matchesSearch =
              query.isEmpty ||
              channel.name.toLowerCase().contains(query) ||
              channel.group.toLowerCase().contains(query) ||
              (channel.id?.toLowerCase().contains(query) ?? false);
          return matchesFilter && matchesFavorite && matchesSearch;
        })
        .toList(growable: false);
  }

  void _selectSection(_AppSection section) {
    setState(() => _section = section);
    if (section == _AppSection.guide && _programmes.isEmpty && !_loadingEpg) {
      _loadEpg();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleFavorite(Channel channel) async {
    final next = {..._favorites};
    if (!next.add(channel.url)) next.remove(channel.url);
    setState(() => _favorites = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', next.toList());
  }

  void _watch(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlayerScreen(channel: channel)),
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    _playlistService.dispose();
    _epgService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 600 &&
            constraints.maxWidth > constraints.maxHeight;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide) _buildNavigationRail(),
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(wide),
                      Expanded(child: _buildSection(context, wide)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _section.index,
                  onDestinationSelected: (index) =>
                      _selectSection(_AppSection.values[index]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.live_tv_outlined),
                      selectedIcon: Icon(Icons.live_tv),
                      label: 'Live',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Guide',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.favorite_border),
                      selectedIcon: Icon(Icons.favorite),
                      label: 'Favorites',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 112,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.divider, width: 0.7)),
      ),
      child: NavigationRail(
        selectedIndex: _section.index,
        labelType: NavigationRailLabelType.all,
        groupAlignment: -0.65,
        onDestinationSelected: (index) =>
            _selectSection(_AppSection.values[index]),
        leading: Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 36),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/branding/kambingtv_logo.png',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.live_tv,
                  color: Color(0xFF07110F),
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv),
            label: Text('Live'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: Text('Guide'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: Text('Favorites'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool wide) {
    final title = switch (_section) {
      _AppSection.live => 'Live TV',
      _AppSection.guide => 'TV Guide',
      _AppSection.favorites => 'Favorites',
    };
    final subtitle = switch (_section) {
      _AppSection.live => 'Discover what is on',
      _AppSection.guide => 'Browse schedules and start watching',
      _AppSection.favorites => 'Your saved channels',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : 20,
        wide ? 22 : 12,
        wide ? 32 : 20,
        10,
      ),
      child: Row(
        children: [
          if (!wide) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.asset(
                'assets/branding/kambingtv_logo.png',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.live_tv, color: Color(0xFF07110F)),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wide ? title : 'KambingTV  ·  $title',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _section == _AppSection.guide
                ? 'Refresh guide'
                : 'Refresh playlist',
            onPressed: _section == _AppSection.guide
                ? (_loadingEpg ? null : _loadEpg)
                : (_loadingPlaylist ? null : () => _loadPlaylist(forceRemote: true)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, bool wide) {
    if (_section == _AppSection.guide) {
      if (_loadingPlaylist) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_playlistError != null) {
        return _buildPlaylistError();
      }
      return GuideScreen(
        channels: _channels,
        programmes: _programmes,
        loading: _loadingEpg,
        error: _epgError,
        onRetry: _loadEpg,
        onWatch: _watch,
      );
    }

    if (_loadingPlaylist) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_playlistError != null) {
      return _buildPlaylistError();
    }
    return _buildChannelBrowser(
      wide,
      favoritesOnly: _section == _AppSection.favorites,
    );
  }

  Widget _buildChannelBrowser(bool wide, {required bool favoritesOnly}) {
    final channels = _visibleChannels(favoritesOnly: favoritesOnly);
    final horizontalPadding = wide ? 32.0 : 20.0;
    final allFilter = _categoryService.buildAllFilter(_channels.length);
    final quickFilters = _categoryService.buildQuickFilters(
      _channels.length,
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
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: favoritesOnly
                        ? 'Search favorites'
                        : 'Search channels, genres, or countries...',
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
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                    'All 200+ Categories (${_genreFilters.length + _countryFilters.length})',
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
            horizontalPadding,
            8,
            horizontalPadding,
            8,
          ),
          child: Row(
            children: [
              Text(
                '${channels.length} channels',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.textMuted),
              ),
              if (_selectedFilter.type != CategoryType.all) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x2200D4AA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x5500D4AA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_selectedFilter.icon} ${_selectedFilter.label}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _selectedFilter = allFilter),
                        child: const Icon(
                          Icons.cancel,
                          size: 14,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: channels.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 52,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          favoritesOnly
                              ? 'Save channels with the heart button to find them here.'
                              : 'No channels match this filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 16,
                          ),
                        ),
                        if (_selectedFilter.type != CategoryType.all ||
                            _searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _selectedFilter = allFilter);
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reset Category & Search Filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1500
                        ? 6
                        : constraints.maxWidth >= 1100
                        ? 5
                        : constraints.maxWidth >= 750
                        ? 4
                        : constraints.maxWidth >= 480
                        ? 3
                        : 2;
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        24,
                      ),
                      itemCount: channels.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: wide ? 1.65 : 1.15,
                      ),
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        return _ChannelTile(
                          channel: channel,
                          isFavorite: _favorites.contains(channel.url),
                          autofocus: index == 0,
                          onFavorite: () => _toggleFavorite(channel),
                          onTap: () => _watch(channel),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlaylistError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 54, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Could not load the KambingTV playlist',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _playlistError ?? 'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadPlaylist,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatefulWidget {
  const _ChannelTile({
    required this.channel,
    required this.isFavorite,
    required this.autofocus,
    required this.onFavorite,
    required this.onTap,
  });

  final Channel channel;
  final bool isFavorite;
  final bool autofocus;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _focused ? 1.035 : 1,
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
          onFocusChange: (focused) => setState(() => _focused = focused),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: ChannelAvatar(
                      channel: widget.channel,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (widget.channel.drm.isDrm)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.lock, size: 14, color: Colors.amber),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: widget.isFavorite
                          ? 'Remove favorite'
                          : 'Add favorite',
                      onPressed: widget.onFavorite,
                      icon: Icon(
                        widget.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 18,
                      ),
                    ),
                  ],
                ),
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
        ),
      ),
    );
  }
}
