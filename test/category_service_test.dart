import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/models/channel.dart';
import 'package:opentv/services/category_service.dart';

void main() {
  const service = CategoryService();

  final testChannels = [
    const Channel(name: 'TVRI Nasional', url: 'http://test/1', group: 'Nasional'),
    const Channel(name: 'RCTI Live', url: 'http://test/2', group: 'Indonesia Channels'),
    const Channel(name: 'BeIN Sports 1', url: 'http://test/3', group: 'Sports'),
    const Channel(name: 'ESPN HD', url: 'http://test/4', group: 'Sports Channels'),
    const Channel(name: 'CNN US', url: 'http://test/5', group: 'United States'),
    const Channel(name: 'BBC One', url: 'http://test/6', group: 'United Kingdom'),
    const Channel(name: 'NHK World', url: 'http://test/7', group: 'Japan'),
    const Channel(name: 'Cartoon Net', url: 'http://test/8', group: 'Kids Channels'),
  ];

  group('CategoryService tests', () {
    test('flagForCountry returns valid flag emojis', () {
      expect(CategoryService.flagForCountry('Indonesia'), '🇮🇩');
      expect(CategoryService.flagForCountry('United States'), '🇺🇸');
      expect(CategoryService.flagForCountry('Japan'), '🇯🇵');
      expect(CategoryService.flagForCountry('Unknown Country XYZ'), '🌐');
    });

    test('buildGenreFilters groups and sums channels properly', () {
      final counts = service.countGroups(testChannels);
      final genres = service.buildGenreFilters(counts);

      final indo = genres.firstWhere((g) => g.id == 'genre:indonesia');
      expect(indo.count, 2); // 'Nasional' + 'Indonesia Channels'
      expect(indo.matches(testChannels[0]), isTrue);
      expect(indo.matches(testChannels[1]), isTrue);
      expect(indo.matches(testChannels[2]), isFalse);

      final sports = genres.firstWhere((g) => g.id == 'genre:sports');
      expect(sports.count, 2); // 'Sports' + 'Sports Channels'
      expect(sports.matches(testChannels[2]), isTrue);
      expect(sports.matches(testChannels[3]), isTrue);
    });

    test('buildCountryFilters lists countries with counts', () {
      final counts = service.countGroups(testChannels);
      final countries = service.buildCountryFilters(counts);

      expect(countries.any((c) => c.label == 'United States' && c.count == 1), isTrue);
      expect(countries.any((c) => c.label == 'United Kingdom' && c.count == 1), isTrue);
      expect(countries.any((c) => c.label == 'Japan' && c.count == 1), isTrue);
    });

    test('buildQuickFilters includes All, featured genres and major countries', () {
      final counts = service.countGroups(testChannels);
      final genres = service.buildGenreFilters(counts);
      final countries = service.buildCountryFilters(counts);
      final quick = service.buildQuickFilters(testChannels.length, genres, countries);

      expect(quick.first.id, 'all');
      expect(quick.first.count, 8);
      expect(quick.any((q) => q.id == 'genre:indonesia'), isTrue);
      expect(quick.any((q) => q.id == 'genre:sports'), isTrue);
      expect(quick.any((q) => q.label == 'United States'), isTrue);
    });
  });
}
