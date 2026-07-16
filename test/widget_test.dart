import 'package:flutter_test/flutter_test.dart';
import 'package:noti/theme/noti_theme.dart';

void main() {
  test('unknown theme settings fall back to the Noti preset', () {
    expect(NotiThemePreset.fromStorage('unknown'), NotiThemePreset.main);
    expect(NotiThemePreset.fromStorage(null), NotiThemePreset.main);
    expect(NotiAppearance.fromStorage('unknown'), NotiAppearance.light);
    expect(NotiAppearance.fromStorage(null), NotiAppearance.light);
  });

  test('every color and appearance uses a matching accessible palette', () {
    for (final appearance in NotiAppearance.values) {
      for (final preset in NotiThemePreset.values) {
        final palette = NotiPalette.forPreset(preset, appearance: appearance);
        final theme = NotiTheme.build(preset, appearance: appearance);

        expect(theme.brightness, appearance.brightness);
        expect(theme.colorScheme.primary, palette.primary);
        expect(theme.colorScheme.onPrimary, palette.onPrimary);
        expect(theme.colorScheme.primary, isNot(theme.colorScheme.onPrimary));
        expect(
          theme.filledButtonTheme.style?.foregroundColor?.resolve({}),
          palette.onPrimary,
        );
      }
    }
  });
}
