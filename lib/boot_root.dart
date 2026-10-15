import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'boot.dart';
import 'core/app_paths.dart';
import 'core/device_store.dart';
import 'data/db/errors.dart';
import 'design/app_logo.dart';
import 'design/theme.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'fake/data_providers.dart';
import 'fake/health.dart';
import 'fake/store.dart';
import 'strings.dart';

/// The first thing the program does: open the shop's data, then show the app (or a clear explanation of what is wrong).
class BootRoot extends StatefulWidget {
  const BootRoot({super.key, this.paths});

  /// For tests of the start-up itself; the app uses the real folder of this computer.
  final AppPaths? paths;

  @override
  State<BootRoot> createState() => _BootRootState();
}

class _BootRootState extends State<BootRoot> {
  late final AppPaths _paths = widget.paths ?? createAppPaths();
  late final DeviceStore _store = createDeviceStore();
  BootOutcome? _outcome;
  int _generation = 0;
  DataMode? _mode;
  String _busyText = const Strings().bootOpening;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start({DataMode? mode}) async {
    _mode = mode ?? _mode ?? await loadMode(_paths);
    final m = _mode!;
    setState(() {
      _outcome = null;
      _busyText = m == DataMode.demo ? const Strings().bootDemoPreparing : const Strings().bootOpening;
    });
    final o = await bootApp(paths: _paths, mode: m);
    if (!mounted) return;
    setState(() {
      _outcome = o;
      _generation++;
    });
  }

  Future<void> _switch(DataMode m) async {
    final o = _outcome;
    if (o is BootReady) {
      await o.data.close(); // the other file opens next; nothing of the current one is left half-written
    }
    await saveMode(_paths, m);
    await _start(mode: m);
  }

  @override
  Widget build(BuildContext context) {
    final o = _outcome;
    if (o is BootReady) {
      return ProviderScope(
        key: ValueKey('shop-$_generation'),
        overrides: [
          appDataProvider.overrideWithValue(o.data),
          bootstrapProvider.overrideWithValue(o.boot),
          deviceStoreProvider.overrideWithValue(_store),
          dataDirProvider.overrideWithValue(o.dataDir.isEmpty ? null : o.dataDir),
          dbFilePathProvider.overrideWithValue(o.dataDir.isEmpty ? null : o.location),
          appModeProvider.overrideWith(() => _FixedMode(o.mode)),
          modeSwitcherProvider.overrideWithValue(_switch),
          clockProvider.overrideWith((ref) {
            final n = DateTime.now();
            return DateTime(n.year, n.month, n.day, n.hour, n.minute);
          }),
        ],
        child: ErpApp(initialLocation: o.needsSetup ? '/wizard' : (o.swap != null ? '/health' : '/'), dbLocation: o.location, runChecks: o.mode == DataMode.real),
      );
    }
    final theme = buildTheme(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    return MaterialApp(
      title: 'ASK ERP 2.0',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: o is BootProblem ? ProblemScreen(problem: o, onRetry: () => _start(), onDemo: () => _switch(DataMode.demo), onReal: () => _switch(DataMode.real)) : SplashScreen(text: _busyText),
    );
  }
}

class _FixedMode extends AppModeNotifier {
  _FixedMode(this.m);
  final DataMode m;
  @override
  DataMode build() => m;
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const AppLogo(size: 96),
            const SizedBox(height: 20),
            Text('ASK ERP 2.0', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(text, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ]),
        ),
      );
}

/// The data could not be opened. Says what is wrong in plain words, never shows a code, and never touches the file.
class ProblemScreen extends StatelessWidget {
  const ProblemScreen({super.key, required this.problem, required this.onRetry, this.onDemo, this.onReal});
  final BootProblem problem;
  final VoidCallback onRetry;
  final VoidCallback? onDemo, onReal;

  static (String, String) words(DatabaseOpenException e) {
    const l = Strings();
    return switch (e.problem) {
      DbProblem.tooNew => (l.probTooNewTitle, l.probTooNewText('${e.fileVersion}', '${e.appVersion}')),
      DbProblem.locked => (l.probLockedTitle, l.probLockedText),
      DbProblem.readOnly => (l.probReadOnlyTitle, l.probReadOnlyText),
      DbProblem.cannotOpen => (l.probCannotOpenTitle, l.probCannotOpenText),
      DbProblem.notDatabase => (l.probNotDbTitle, l.probNotDbText),
      DbProblem.corrupt => (l.probCorruptTitle, l.probCorruptText),
      DbProblem.diskFull => (l.probDiskFullTitle, l.probDiskFullText),
      DbProblem.other => (l.probOtherTitle, l.probOtherText),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (title, text) = words(problem.error);
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: AppLogo(size: 72)),
              const SizedBox(height: 16),
              Row(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error), const SizedBox(width: 10), Expanded(child: Text(title, style: th.titleLarge))]),
              const SizedBox(height: 12),
              Text(text, key: const ValueKey('problemText'), style: th.bodyLarge),
              if (problem.error.detail.isNotEmpty) ...[
                const SizedBox(height: 10),
                SelectableText(problem.error.detail, key: const ValueKey('problemDetail'), style: th.bodySmall),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(key: const ValueKey('problemRetry'), onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(l.probRetry)),
              if (problem.mode == DataMode.real && onDemo != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(key: const ValueKey('problemDemo'), onPressed: onDemo, icon: const Icon(Icons.school_outlined), label: Text(l.probDemo)),
              ],
              if (problem.mode == DataMode.demo && onReal != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: onReal, icon: const Icon(Icons.storefront_outlined), label: Text(l.probBackToShop)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Shown over everything when the data file fails its health check: the owner is told to stop and restore from a backup.
class DamagedFileScreen extends ConsumerWidget {
  const DamagedFileScreen({super.key, required this.details});
  final List<String> details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Icon(Icons.healing_outlined, color: context.c.danger, size: 32), const SizedBox(width: 10), Expanded(child: Text(l.damagedTitle, style: th.titleLarge))]),
              const SizedBox(height: 12),
              Text(l.damagedText, style: th.bodyLarge),
              const SizedBox(height: 12),
              Text(l.damagedWhat, style: th.labelMedium),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: context.c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.s)), child: Text(details.take(6).join('\n'), key: const ValueKey('damageDetails'), style: th.bodySmall)),
              const SizedBox(height: 20),
              FilledButton.icon(key: const ValueKey('restoreFromBackup'), onPressed: () => toast(context, l.restoreLater), icon: const Icon(Icons.restore), label: Text(l.damagedRestore)),
              const SizedBox(height: 10),
              OutlinedButton(key: const ValueKey('continueAnyway'), onPressed: () => ref.read(fileHealthProvider.notifier).set(FileHealth.ok), child: Text(l.damagedCarryOn)),
            ]),
          ),
        ),
      ),
    );
  }
}
