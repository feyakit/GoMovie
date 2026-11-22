import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../app_scope.dart';
import '../widgets/group_card.dart';
import 'settings_rows.dart';

const themeModes = {'system': '自动（跟随系统）', 'light': '浅色', 'dark': '深色'};

const displayModes = {
  'auto': '自动识别设备',
  'television': '电视',
  'phone': '手机',
  'pad': '平板',
  'window': '窗口',
};

Map<String, String> get availableDisplayModes => {
  for (final MapEntry(:key, :value) in displayModes.entries)
    if (desktopPlatform || key != 'window') key: value,
};

String platformDisplayMode(String mode) =>
    mode == 'window' && !desktopPlatform ? 'pad' : mode;

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    final television = AppScope.of(context).television;
    return Column(
      spacing: 12,
      children: [
        GroupCard(
          children: [
            SettingsTile(
              title: '主题模式',
              subtitle: themeModes[store.themeMode] ?? themeModes['system']!,
              onTap: () async {
                final selection = await showOptionDialog(
                  context,
                  title: '主题模式',
                  options: themeModes,
                  selected: store.themeMode,
                );
                if (selection != null && context.mounted) {
                  await saveSetting(
                    context,
                    () => store.setThemeMode(selection),
                  );
                }
              },
            ),
            const Divider(indent: 16, endIndent: 16),
            if (!television)
              SwitchTile(
                title: '在主页底栏显示历史',
                subtitle: '关闭后仍可在「我的」里打开观看记录',
                value: store.historyTab,
                onChanged: (value) =>
                    saveSetting(context, () => store.setHistoryTab(value)),
              )
            else
              SwitchTile(
                title: '搜索用字母键盘',
                subtitle: '开启后按确认键弹出字母键盘，可按拼音首字母搜；关闭时使用系统输入法',
                value: store.televisionKeyboard,
                onChanged: (value) => saveSetting(
                  context,
                  () => store.setTelevisionKeyboard(value),
                ),
              ),
          ],
        ),
        GroupCard(
          children: [
            SettingsTile(
              title: '界面模式',
              subtitle: displayModes[platformDisplayMode(store.displayMode)]!,
              onTap: () async {
                final selection = await showOptionDialog(
                  context,
                  title: '界面模式',
                  options: availableDisplayModes,
                  selected: platformDisplayMode(store.displayMode),
                );
                if (selection != null && context.mounted) {
                  await saveSetting(
                    context,
                    () => store.setDisplayMode(selection),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
