import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Offline catalogue loads and savings are independent of old app',
    () async {
      SharedPreferences.setMockInitialValues({
        'tertiary.saved.v1': ['nmc:1', 'gtec:881'],
      });
      final store = TertiaryStore();
      await store.load();
      expect(store.institutions.length, greaterThan(500));
      expect(store.saved, {'gtec:881'});
      expect(store.institutions.expand((i) => i.regions).toSet().length, 16);
      expect(store.institutions.expand((i) => i.recordIds).length, 792);
      expect(
        store.institutions.where(
          (i) => i.name.toLowerCase().contains('senior high'),
        ),
        isEmpty,
      );
      expect(
        store.institutions.where((i) => i.group == 'Skills & fashion'),
        isNotEmpty,
      );
      await store.toggleSaved(store.institutions.first.id);
      final reloaded = TertiaryStore();
      await reloaded.load();
      expect(reloaded.saved, contains(store.institutions.first.id));
    },
  );
}
