import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/demo.dart';

/// A standalone entry point that draws the agent's compact suggestion on
/// the demo app. `?s=1` the card, `?s=2` accepting, `?s=3` Details.
void main() => runApp(const _PreviewApp());

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

AgentSuggestion _offer(AppLocalizations l10n) {
  final plan = AgentPlan(
    id: 'p1',
    changes: [
      PlanChange(
        kind: PlanChangeKind.addTask,
        title: l10n.suggestionPreviewTask,
        minutes: 120,
        at: DateTime(2026, 11, 6, 15),
      ),
    ],
  );

  return AgentSuggestion(
    id: 's1',
    text: l10n.suggestionPreviewText,
    action: SuggestionAction(label: l10n.agentSuggestionAccept, plan: plan),
    opening: AgentReply(text: l10n.suggestionPreviewText, plan: plan),
  );
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.current,
    locale: previewLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _scene == 2
        ? const _Accepting()
        : const DemoApp(suggestion: _offer),
    builder: (context, child) => _Scene(child: child!),
  );
}

/// The card on its own, with the spinner where Aceitar was.
class _Accepting extends StatelessWidget {
  const _Accepting();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s6),
          BlocProvider<SuggestionCubit>(
            create: (context) => _Held(_offer(context.l10n)),
            child: const SuggestionCard(accepting: true),
          ),
        ],
      ),
    ),
  );
}

class _NoRepository implements AgentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Held extends SuggestionCubit {
  _Held(AgentSuggestion held) : super(repository: _NoRepository()) {
    emit(held);
  }
}

class _Scene extends StatefulWidget {
  const _Scene({required this.child});

  final Widget child;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  @override
  void initState() {
    super.initState();
    if (_scene != 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      Element? card;
      void find(Element e) {
        if (card != null) return;
        if (e.widget is SuggestionCard) {
          card = e;
        } else {
          e.visitChildren(find);
        }
      }

      WidgetsBinding.instance.rootElement?.visitChildren(find);
      final found = card;
      if (found != null) {
        unawaited(
          showAgentSheet(found, suggestion: _offer(found.l10n)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
