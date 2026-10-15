import 'dart:async';

import 'package:agent/src/agent_cubit.dart';
import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:agent/src/view/apply_plan.dart';
import 'package:agent/src/view/plan_card.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// Opens the conversation over Tempo, about [day].
///
/// The sheet is a route of its own, which need not sit under whatever
/// provides the conversation, the agent's routes and the day, so it is handed
/// all three from here.
Future<void> showAgentSheet(BuildContext context, {DateTime? day}) {
  final agent = context.read<AgentCubit>();
  final repository = context.read<AgentRepository>();
  final timeline = context.read<TimelineBloc>();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.32),
    builder: (_) => RepositoryProvider.value(
      value: repository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: agent),
          BlocProvider.value(value: timeline),
        ],
        child: FractionallySizedBox(
          heightFactor: 0.88,
          alignment: Alignment.bottomCenter,
          child: AgentSheet(day: day),
        ),
      ),
    ),
  );
}

/// {@template agent_sheet}
/// The conversation with the agent.
///
/// Empty, it offers what is most often asked. Then it is the conversation:
/// what the user said, what the agent did (one ticked line per step), what
/// it answered, and the plan it proposes, which nothing makes until Aplicar.
/// {@endtemplate}
class AgentSheet extends StatefulWidget {
  /// {@macro agent_sheet}
  const AgentSheet({this.day, super.key});

  /// The day Tempo is showing.
  final DateTime? day;

  @override
  State<AgentSheet> createState() => _AgentSheetState();
}

class _AgentSheetState extends State<AgentSheet> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final said = (text ?? _field.text).trim();
    if (said.isEmpty) return;

    _field.clear();
    unawaited(context.read<AgentCubit>().send(said, day: widget.day));
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadius + 4),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BlocConsumer<AgentCubit, AgentState>(
            listenWhen: (a, b) =>
                a.entries.length != b.entries.length || a.busy != b.busy,
            listener: (_, _) => _toEnd(),
            builder: (context, state) {
              return Column(
                children: [
                  const _Grabber(),
                  _Header(
                    onReset: state.entries.isEmpty
                        ? null
                        : () => context.read<AgentCubit>().reset(),
                  ),
                  Expanded(
                    child: state.entries.isEmpty && !state.busy
                        ? _Welcome(onPick: _send)
                        : ListView(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s5,
                              AppSpacing.s2,
                              AppSpacing.s5,
                              AppSpacing.s4,
                            ),
                            children: [
                              for (final entry in state.entries)
                                switch (entry) {
                                  UserEntry(:final text) => _Said(text),
                                  ReplyEntry() => _Answer(
                                    entry: entry,
                                    onAdjust: _focus.requestFocus,
                                  ),
                                },
                              if (state.busy) const _Thinking(),
                              if (state.failure case final failure?)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.s2,
                                  ),
                                  child: Text(
                                    failure.message ?? l10n.agentFailure,
                                    style: AppTypography.label.copyWith(
                                      color: AppColors.dangerInk,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  _Composer(
                    controller: _field,
                    focusNode: _focus,
                    hint: state.entries.isEmpty
                        ? l10n.agentInputHint
                        : l10n.agentReplyHint,
                    busy: state.busy,
                    onSend: _send,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: AppSpacing.s3, bottom: AppSpacing.s1),
      decoration: BoxDecoration(
        color: AppColors.fillStrong,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onReset});

  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s2,
        AppSpacing.s3,
        AppSpacing.s2,
      ),
      child: Row(
        children: [
          const AppIcon(iconData: AppIcons.agent, size: 26),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(l10n.appName(AppBrand.id), style: AppTypography.title),
          ),
          if (onReset != null)
            Tooltip(
              message: l10n.agentNewConversation,
              child: AppIconButton(
                iconData: AppIcons.newConversation,
                size: AppSpacing.s5,
                color: AppColors.ink2,
                onPressed: onReset!,
              ),
            ),
          Tooltip(
            message: l10n.agentClose,
            child: AppIconButton(
              iconData: AppIcons.close,
              size: AppSpacing.s5,
              color: AppColors.ink2,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chips = [
      (AppIcons.prioritize, l10n.agentChipAfternoon),
      (AppIcons.calendar, l10n.agentChipStudy),
      (AppIcons.timer, l10n.agentChipLate),
      (AppIcons.time, l10n.agentChipTomorrow),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s5,
        AppSpacing.s5,
        AppSpacing.s4,
      ),
      children: [
        Text(l10n.agentGreeting, style: AppTypography.headline),
        const SizedBox(height: AppSpacing.s2),
        Text(l10n.agentGreetingHint, style: AppTypography.label),
        const SizedBox(height: AppSpacing.s5),
        for (final (icon, text) in chips) ...[
          Material(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              onTap: () => onPick(text),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s3,
                ),
                child: Row(
                  children: [
                    AppIcon(
                      iconData: icon,
                      size: AppSpacing.s5,
                      color: AppColors.ink2,
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(child: Text(text, style: AppTypography.body)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
        ],
      ],
    );
  }
}

/// What the user said, on the right, in ink.
class _Said extends StatelessWidget {
  const _Said(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.s4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: AppTypography.body.copyWith(color: AppColors.bg),
        ),
      ),
    );
  }
}

/// What the agent did and said, and its plan.
class _Answer extends StatelessWidget {
  const _Answer({required this.entry, required this.onAdjust});

  final ReplyEntry entry;

  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final reply = entry.reply;
    final plan = reply.plan;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in reply.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: Row(
                children: [
                  const AppIcon(
                    iconData: AppIcons.check,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(child: Text(step, style: AppTypography.label)),
                ],
              ),
            ),
          if (reply.steps.isNotEmpty) const SizedBox(height: AppSpacing.s1),
          Text(reply.text, style: AppTypography.body),
          if (plan != null) ...[
            const SizedBox(height: AppSpacing.s3),
            PlanCard(
              plan: plan,
              status: entry.status,
              onAdjust: onAdjust,
              onApply: () async {
                final navigator = Navigator.of(context);
                if (await applyAgentPlan(context, plan)) navigator.pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.ink3,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(context.l10n.agentThinking, style: AppTypography.label),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s1,
        AppSpacing.s2,
        AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s3,
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final ready = !busy && controller.text.trim().isNotEmpty;

              return Semantics(
                button: true,
                label: context.l10n.agentSend,
                child: GestureDetector(
                  onTap: ready ? onSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ready ? AppColors.accent : AppColors.fillStrong,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        iconData: AppIcons.arrowUp,
                        size: 18,
                        color: ready ? AppColors.onAccent : AppColors.ink3,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
