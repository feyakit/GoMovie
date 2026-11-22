import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../../models.dart';
import '../search/search_page.dart';
import '../modules/modules_page.dart';
import '../shell/app_shell.dart';
import 'source_picker.dart';

Future<void> pickSource(BuildContext anchor, LocalStore store) async {
  final value = await SourcePicker.show(anchor, store);
  if (value == null || !anchor.mounted) return;
  if (value == SourcePicker.manageSourceId) {
    await openPage<void>(anchor, (_) => ModulesPage(store: store));
    return;
  }
  if (value == store.source) return;
  try {
    await store.setSource(value);
  } catch (_) {
    if (!anchor.mounted) return;
    ScaffoldMessenger.maybeOf(
      anchor,
    )?.showSnackBar(const SnackBar(content: Text('未能切换站源，请重试')));
  }
}

Future<void> openSearch(
  BuildContext context,
  LocalStore store,
  SourceSite source, {
  String query = '',
}) => openPage<void>(
  context,
  (_) => SearchPage(store: store, source: source, query: query),
);
