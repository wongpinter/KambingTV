import '../models/channel.dart';

enum CategoryType {
  all,
  featured,
  genre,
  country,
  raw,
}

class CategoryFilter {
  const CategoryFilter({
    required this.id,
    required this.label,
    required this.icon,
    required this.type,
    this.count = 0,
    this.targetGroups = const {},
    this.rawGroup,
    this.subtitle,
  });

  final String id;
  final String label;
  final String icon;
  final CategoryType type;
  final int count;
  final Set<String> targetGroups;
  final String? rawGroup;
  final String? subtitle;

  CategoryFilter copyWith({int? count}) {
    return CategoryFilter(
      id: id,
      label: label,
      icon: icon,
      type: type,
      count: count ?? this.count,
      targetGroups: targetGroups,
      rawGroup: rawGroup,
      subtitle: subtitle,
    );
  }

  bool matches(Channel channel) {
    if (type == CategoryType.all) return true;
    if (rawGroup != null) return channel.group == rawGroup;
    if (targetGroups.isNotEmpty) return targetGroups.contains(channel.group);
    return channel.group == label;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryFilter && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CategoryService {
  const CategoryService();

  static const Map<String, String> countryCodeMap = {
    'Afghanistan': 'AF', 'Albania': 'AL', 'Algeria': 'DZ', 'Andorra': 'AD', 'Angola': 'AO',
    'Antigua and Barbuda': 'AG', 'Argentina': 'AR', 'Armenia': 'AM', 'Aruba': 'AW', 'Australia': 'AU',
    'Austria': 'AT', 'Azerbaijan': 'AZ', 'Bahamas': 'BS', 'Bahrain': 'BH', 'Bangladesh': 'BD',
    'Barbados': 'BB', 'Belarus': 'BY', 'Belgium': 'BE', 'Belize': 'BZ', 'Benin': 'BJ',
    'Bolivia': 'BO', 'Bonaire': 'BQ', 'Bosnia and Herzegovina': 'BA', 'Brazil': 'BR',
    'British Virgin Islands': 'VG', 'Bulgaria': 'BG', 'Burkina Faso': 'BF', 'Burundi': 'BI',
    'Cambodia': 'KH', 'Cameroon': 'CM', 'Canada': 'CA', 'Cape Verde': 'CV', 'Chad': 'TD',
    'Chile': 'CL', 'China': 'CN', 'Colombia': 'CO', 'Costa Rica': 'CR', 'Croatia': 'HR',
    'Cuba': 'CU', 'Curacao': 'CW', 'Cyprus': 'CY', 'Czech Republic': 'CZ',
    'Democratic Republic of the Congo': 'CD', 'Denmark': 'DK', 'Dominican Republic': 'DO',
    'Ecuador': 'EC', 'Egypt': 'EG', 'El Salvador': 'SV', 'Eritrea': 'ER', 'Estonia': 'EE',
    'Ethiopia': 'ET', 'Finland': 'FI', 'France': 'FR', 'French Guiana': 'GF', 'Georgia': 'GE',
    'Germany': 'DE', 'Ghana': 'GH', 'Greece': 'GR', 'Guadeloupe': 'GP', 'Guam': 'GU',
    'Guatemala': 'GT', 'Guinea': 'GN', 'Guyana': 'GY', 'Haiti': 'HT', 'Honduras': 'HN',
    'Hong Kong': 'HK', 'Hungary': 'HU', 'Iceland': 'IS', 'India': 'IN', 'Indonesia': 'ID',
    'Iran': 'IR', 'Iraq': 'IQ', 'Ireland': 'IE', 'Israel': 'IL', 'Italy': 'IT',
    'Ivory Coast': 'CI', 'Jamaica': 'JM', 'Japan': 'JP', 'Jordan': 'JO', 'Kazakhstan': 'KZ',
    'Kenya': 'KE', 'Korea': 'KR', 'Kosovo': 'XK', 'Kuwait': 'KW', 'Laos': 'LA',
    'Latvia': 'LV', 'Lebanon': 'LB', 'Libya': 'LY', 'Lithuania': 'LT', 'Luxembourg': 'LU',
    'Malaysia': 'MY', 'Maldives': 'MV', 'Mali': 'ML', 'Malta': 'MT', 'Martinique': 'MQ',
    'Mauritania': 'MR', 'Mexico': 'MX', 'Moldova': 'MD', 'Monaco': 'MC', 'Mongolia': 'MN',
    'Montenegro': 'ME', 'Morocco': 'MA', 'Mozambique': 'MZ', 'Myanmar': 'MM', 'Namibia': 'NA',
    'Nepal': 'NP', 'Netherlands': 'NL', 'New Caledonia': 'NC', 'New Zealand': 'NZ',
    'Nicaragua': 'NI', 'Niger': 'NE', 'Nigeria': 'NG', 'North Korea': 'KP', 'North Macedonia': 'MK',
    'Norway': 'NO', 'Oman': 'OM', 'Pakistan': 'PK', 'Palestine': 'PS', 'Panama': 'PA',
    'Papua New Guinea': 'PG', 'Paraguay': 'PY', 'Peru': 'PE', 'Philippines': 'PH', 'Poland': 'PL',
    'Portugal': 'PT', 'Puerto Rico': 'PR', 'Qatar': 'QA', 'Republic of the Congo': 'CG',
    'Romania': 'RO', 'Russia': 'RU', 'Rwanda': 'RW', 'Saint Kitts and Nevis': 'KN',
    'Saint Lucia': 'LC', 'Saudi Arabia': 'SA', 'Senegal': 'SN', 'Serbia': 'RS',
    'Sierra Leone': 'SL', 'Singapore': 'SG', 'Sint Maarten': 'SX', 'Slovakia': 'SK',
    'Slovenia': 'SI', 'South Africa': 'ZA', 'South Korea': 'KR', 'Spain': 'ES',
    'Sri Lanka': 'LK', 'Sudan': 'SD', 'Suriname': 'SR', 'Sweden': 'SE', 'Switzerland': 'CH',
    'Syria': 'SY', 'Taiwan': 'TW', 'Tanzania': 'TZ', 'Thailand': 'TH', 'Togo': 'TG',
    'Trinidad and Tobago': 'TT', 'Tunisia': 'TN', 'Turkey': 'TR', 'Turkiye': 'TR',
    'Turkmenistan': 'TM', 'Uganda': 'UG', 'Ukraine': 'UA', 'United Arab Emirates': 'AE',
    'United Kingdom': 'GB', 'United States': 'US', 'Uruguay': 'UY', 'Uzbekistan': 'UZ',
    'Venezuela': 'VE', 'Vietnam': 'VN', 'Western Sahara': 'EH', 'Yemen': 'YE', 'Zimbabwe': 'ZW'
  };

  static String flagForCountry(String country) {
    final code = countryCodeMap[country];
    if (code == null || code.length != 2) return '🌐';
    return String.fromCharCodes(
      code.toUpperCase().runes.map((rune) => rune + 127397),
    );
  }

  static const Set<String> indonesiaGroups = {
    'Indonesia Channels',
    'Nasional',
    'TVRI',
    'TV HIBURAN',
    'Indonesian Entertainment & Movies',
    'VOD INDO',
  };

  static const Set<String> sportsGroups = {
    'Sports',
    'Sports Channels',
    'WorldCup 2026',
  };

  static const Set<String> newsGroups = {
    'News',
    'News Channel',
    'News Channels',
  };

  static const Set<String> moviesGroups = {
    'Movies Channels',
    'Premium Movies',
    'Series Channels',
  };

  static const Set<String> musicGroups = {
    'Music',
    'Music Channels',
    'Internet Radio',
  };

  static const Set<String> kidsGroups = {
    'Kids',
    'Kids Channels',
    'Animation / Anime Channels',
    'Family Channels',
  };

  static const Set<String> documentaryGroups = {
    'Documentary Channels',
    'Knowledge and Documentary',
  };

  static const Set<String> entertainmentGroups = {
    'Entertainment',
    'Entertainment Channels',
    'Entertainment & LifeStyle',
    'Comedy Channels',
    'Auto / Motor / Otomotif Channels',
  };

  static const Set<String> religiousGroups = {
    'Religious Channels',
    'Christian Channels',
  };

  static const Set<String> internationalGroups = {
    'International',
    'General Channels',
    'Local Channels',
    'Trial Channel',
  };

  static const Set<String> knownNonCountryGroups = {
    'Indonesia Channels', 'Nasional', 'TVRI', 'TV HIBURAN', 'Indonesian Entertainment & Movies', 'VOD INDO',
    'Sports', 'Sports Channels', 'WorldCup 2026',
    'News', 'News Channel', 'News Channels',
    'Movies Channels', 'Premium Movies', 'Series Channels',
    'Music', 'Music Channels', 'Internet Radio',
    'Kids', 'Kids Channels', 'Animation / Anime Channels', 'Family Channels',
    'Documentary Channels', 'Knowledge and Documentary',
    'Entertainment', 'Entertainment Channels', 'Entertainment & LifeStyle', 'Comedy Channels', 'Auto / Motor / Otomotif Channels',
    'Religious Channels', 'Christian Channels',
    'International', 'General Channels', 'Local Channels', 'Trial Channel',
    'Italy Channels', 'Mediacorp Singapore', 'UAE & Arab', 'Other',
  };

  CategoryFilter buildAllFilter(int totalCount) {
    return CategoryFilter(
      id: 'all',
      label: 'All Channels',
      icon: '📺',
      type: CategoryType.all,
      count: totalCount,
      subtitle: 'Complete catalog',
    );
  }

  Map<String, int> countGroups(List<Channel> channels) {
    final counts = <String, int>{};
    for (final channel in channels) {
      counts[channel.group] = (counts[channel.group] ?? 0) + 1;
    }
    return counts;
  }

  int countForGroups(Map<String, int> groupCounts, Set<String> groups) {
    return groups.fold<int>(
      0,
      (sum, group) => sum + (groupCounts[group] ?? 0),
    );
  }

  List<CategoryFilter> buildGenreFilters(Map<String, int> counts) {
    final list = <CategoryFilter>[
      CategoryFilter(
        id: 'genre:indonesia',
        label: 'Indonesia',
        icon: '🇮🇩',
        type: CategoryType.featured,
        count: countForGroups(counts, indonesiaGroups),
        targetGroups: indonesiaGroups,
        subtitle: 'National, local & entertainment',
      ),
      CategoryFilter(
        id: 'genre:sports',
        label: 'Sports & Live',
        icon: '⚽',
        type: CategoryType.genre,
        count: countForGroups(counts, sportsGroups),
        targetGroups: sportsGroups,
        subtitle: 'Football, racing, events & cups',
      ),
      CategoryFilter(
        id: 'genre:news',
        label: 'News & Current Affairs',
        icon: '📰',
        type: CategoryType.genre,
        count: countForGroups(counts, newsGroups),
        targetGroups: newsGroups,
        subtitle: 'Breaking news & world reports',
      ),
      CategoryFilter(
        id: 'genre:movies',
        label: 'Movies & Series',
        icon: '🎬',
        type: CategoryType.genre,
        count: countForGroups(counts, moviesGroups),
        targetGroups: moviesGroups,
        subtitle: 'Cinema, box office & dramas',
      ),
      CategoryFilter(
        id: 'genre:kids',
        label: 'Kids & Animation',
        icon: '👶',
        type: CategoryType.genre,
        count: countForGroups(counts, kidsGroups),
        targetGroups: kidsGroups,
        subtitle: 'Cartoons, anime & family',
      ),
      CategoryFilter(
        id: 'genre:music',
        label: 'Music & Radio',
        icon: '🎵',
        type: CategoryType.genre,
        count: countForGroups(counts, musicGroups),
        targetGroups: musicGroups,
        subtitle: 'Hits, concerts & streams',
      ),
      CategoryFilter(
        id: 'genre:documentary',
        label: 'Documentary & Science',
        icon: '📚',
        type: CategoryType.genre,
        count: countForGroups(counts, documentaryGroups),
        targetGroups: documentaryGroups,
        subtitle: 'Nature, history & knowledge',
      ),
      CategoryFilter(
        id: 'genre:entertainment',
        label: 'Entertainment & Lifestyle',
        icon: '🎭',
        type: CategoryType.genre,
        count: countForGroups(counts, entertainmentGroups),
        targetGroups: entertainmentGroups,
        subtitle: 'Shows, comedy & motorsports',
      ),
      CategoryFilter(
        id: 'genre:religious',
        label: 'Faith & Religious',
        icon: '🕌',
        type: CategoryType.genre,
        count: countForGroups(counts, religiousGroups),
        targetGroups: religiousGroups,
        subtitle: 'Spiritual & religious broadcasts',
      ),
      CategoryFilter(
        id: 'genre:international',
        label: 'International & General',
        icon: '🌐',
        type: CategoryType.genre,
        count: countForGroups(counts, internationalGroups),
        targetGroups: internationalGroups,
        subtitle: 'Global multi-region broadcasts',
      ),
    ];

    // Filter out empty genres
    return list.where((f) => f.count > 0).toList();
  }

  List<CategoryFilter> buildCountryFilters(Map<String, int> counts) {
    final countryNames = counts.keys
        .where((g) => !knownNonCountryGroups.contains(g))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return countryNames.map((name) {
      return CategoryFilter(
        id: 'country:$name',
        label: name,
        icon: flagForCountry(name),
        type: CategoryType.country,
        count: counts[name] ?? 0,
        rawGroup: name,
        subtitle: '$name live channels',
      );
    }).where((f) => f.count > 0).toList();
  }

  List<CategoryFilter> buildRawGroupFilters(Map<String, int> counts) {
    final groups = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return groups.map((g) {
      return CategoryFilter(
        id: 'raw:$g',
        label: g,
        icon: '📁',
        type: CategoryType.raw,
        count: counts[g] ?? 0,
        rawGroup: g,
        subtitle: 'M3U playlist group',
      );
    }).toList();
  }

  List<CategoryFilter> buildQuickFilters(
    int totalCount,
    List<CategoryFilter> genres,
    List<CategoryFilter> countries,
  ) {
    final allFilter = buildAllFilter(totalCount);
    final quick = <CategoryFilter>[allFilter];

    // Featured genres first (e.g. Indonesia, Sports, News, Movies, Kids, Music)
    for (final id in [
      'genre:indonesia',
      'genre:sports',
      'genre:news',
      'genre:movies',
      'genre:kids',
      'genre:music',
      'genre:documentary',
      'genre:entertainment',
      'genre:international',
    ]) {
      final match = genres.cast<CategoryFilter?>().firstWhere(
            (g) => g?.id == id,
            orElse: () => null,
          );
      if (match != null) quick.add(match);
    }

    // Top major countries
    for (final countryName in [
      'United States',
      'United Kingdom',
      'India',
      'Japan',
      'South Korea',
      'Germany',
      'France',
      'Brazil',
      'Australia',
      'Canada',
    ]) {
      final match = countries.cast<CategoryFilter?>().firstWhere(
            (c) => c?.label == countryName,
            orElse: () => null,
          );
      if (match != null) quick.add(match);
    }

    return quick;
  }
}
