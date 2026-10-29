import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';

class CategorySelectorSheet extends StatefulWidget {
  const CategorySelectorSheet({
    super.key,
    required this.selectedFilter,
    required this.allFilter,
    required this.genreFilters,
    required this.countryFilters,
    required this.rawGroupFilters,
    required this.onSelect,
  });

  final CategoryFilter selectedFilter;
  final CategoryFilter allFilter;
  final List<CategoryFilter> genreFilters;
  final List<CategoryFilter> countryFilters;
  final List<CategoryFilter> rawGroupFilters;
  final ValueChanged<CategoryFilter> onSelect;

  static Future<void> show(
    BuildContext context, {
    required CategoryFilter selectedFilter,
    required CategoryFilter allFilter,
    required List<CategoryFilter> genreFilters,
    required List<CategoryFilter> countryFilters,
    required List<CategoryFilter> rawGroupFilters,
    required ValueChanged<CategoryFilter> onSelect,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    if (isWide) {
      return showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
            child: CategorySelectorSheet(
              selectedFilter: selectedFilter,
              allFilter: allFilter,
              genreFilters: genreFilters,
              countryFilters: countryFilters,
              rawGroupFilters: rawGroupFilters,
              onSelect: (filter) {
                Navigator.of(context).pop();
                onSelect(filter);
              },
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.88,
        child: CategorySelectorSheet(
          selectedFilter: selectedFilter,
          allFilter: allFilter,
          genreFilters: genreFilters,
          countryFilters: countryFilters,
          rawGroupFilters: rawGroupFilters,
          onSelect: (filter) {
            Navigator.of(context).pop();
            onSelect(filter);
          },
        ),
      ),
    );
  }

  @override
  State<CategorySelectorSheet> createState() => _CategorySelectorSheetState();
}

class _CategorySelectorSheetState extends State<CategorySelectorSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryFilter> _filterList(List<CategoryFilter> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((item) {
      final matchLabel = item.label.toLowerCase().contains(_searchQuery);
      final matchSubtitle =
          item.subtitle?.toLowerCase().contains(_searchQuery) ?? false;
      final matchRaw = item.rawGroup?.toLowerCase().contains(_searchQuery) ?? false;
      return matchLabel || matchSubtitle || matchRaw;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredGenres = _filterList(widget.genreFilters);
    final filteredCountries = _filterList(widget.countryFilters);
    final filteredRaw = _filterList(widget.rawGroupFilters);

    return Column(
      children: [
        // Top Drag Handle for modal
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categories & Countries',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.selectedFilter.type == CategoryType.all
                          ? 'Showing all ${widget.allFilter.count} live channels'
                          : 'Active: ${widget.selectedFilter.icon} ${widget.selectedFilter.label} (${widget.selectedFilter.count})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.selectedFilter.type != CategoryType.all)
                TextButton.icon(
                  onPressed: () => widget.onSelect(widget.allFilter),
                  icon: const Icon(Icons.clear, size: 16, color: AppColors.accent),
                  label: const Text(
                    'Reset',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search categories, genres or countries...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.elevated,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Tab Bar
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Genres (${filteredGenres.length})'),
            Tab(text: 'Countries (${filteredCountries.length})'),
            Tab(text: 'All Groups (${filteredRaw.length})'),
          ],
        ),
        const Divider(height: 1, color: Colors.white12),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFilterListView(
                items: filteredGenres,
                includeAllOption: true,
              ),
              _buildFilterListView(
                items: filteredCountries,
                includeAllOption: false,
              ),
              _buildFilterListView(
                items: filteredRaw,
                includeAllOption: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterListView({
    required List<CategoryFilter> items,
    required bool includeAllOption,
  }) {
    if (items.isEmpty && !includeAllOption) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No categories match "$_searchQuery"',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final totalRows = items.length + (includeAllOption ? 1 : 0);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: totalRows,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (includeAllOption && index == 0) {
          final isSelected = widget.selectedFilter.type == CategoryType.all;
          return _buildFilterTile(widget.allFilter, isSelected);
        }
        final itemIndex = includeAllOption ? index - 1 : index;
        final filter = items[itemIndex];
        final isSelected = widget.selectedFilter.id == filter.id;
        return _buildFilterTile(filter, isSelected);
      },
    );
  }

  Widget _buildFilterTile(CategoryFilter filter, bool isSelected) {
    return Material(
      color: isSelected
          ? const Color(0x2200D4AA)
          : AppColors.elevated.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.onSelect(filter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : const Color(0xFF1B2332),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  filter.icon,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filter.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppColors.accent : Colors.white,
                      ),
                    ),
                    if (filter.subtitle != null)
                      Text(
                        filter.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : const Color(0xFF232D3F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filter.count}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFF07110F) : AppColors.textMuted,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, size: 20, color: AppColors.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
