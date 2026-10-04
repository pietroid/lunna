import 'dart:developer';

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template a2ui_renderer}
/// Draws an A2UI tree with the app's own widgets.
///
/// The renderer is deliberately dumb. It does not decide what an action means,
/// it does not repair a component it dislikes, and it does not fall back to
/// something plausible: the server has already validated the tree against the
/// same catalog this file implements, so anything unexpected here is a real
/// mismatch between the two halves and is drawn as such rather than hidden.
/// {@endtemplate}
class A2uiRenderer extends StatelessWidget {
  /// {@macro a2ui_renderer}
  const A2uiRenderer({
    required this.component,
    required this.onAction,
    this.enabled = true,
    super.key,
  });

  /// The root of the A2UI tree to draw.
  final A2uiComponent component;

  /// Called with the action a component carried, verbatim.
  final void Function(Map<String, dynamic> action) onAction;

  /// Whether interactive components respond to taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) => _build(component);

  Widget _build(A2uiComponent node) {
    return switch (node.component) {
      'Column' => _column(node),
      'Row' => _row(node),
      'Spacer' => _spacer(node),
      'Divider' => const Divider(color: AppColors.line, height: AppSpacing.s6),
      'Text' => _text(node),
      'Icon' => _icon(node),
      'Image' => _image(node),
      'Card' => _card(node),
      'Badge' => _badge(node),
      'ListItem' => _listItem(node),
      'AppButton' => _button(node),
      'AppIconButton' => _iconButton(node),
      _ => _unsupported(node),
    };
  }

  Widget _column(A2uiComponent node) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: _mainAxis(node.properties['mainAxisAlignment']),
      crossAxisAlignment: _crossAxis(
        node.properties['crossAxisAlignment'],
        fallback: CrossAxisAlignment.start,
      ),
      children: _spaced(node, vertical: true),
    );
  }

  Widget _row(A2uiComponent node) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: _mainAxis(node.properties['mainAxisAlignment']),
      crossAxisAlignment: _crossAxis(
        node.properties['crossAxisAlignment'],
        fallback: CrossAxisAlignment.center,
      ),
      children: _spaced(node, vertical: false),
    );
  }

  /// Children, with the parent's gap inserted between them.
  ///
  /// The gap lives on the parent rather than being a Spacer the agent has to
  /// remember to add. Left to itself a model spaces the first two items and
  /// forgets the third, and the result reads as a rendering bug.
  List<Widget> _spaced(A2uiComponent node, {required bool vertical}) {
    final children = node.children ?? const <A2uiComponent>[];
    final gap = _gap(node.properties['gap']);
    final widgets = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      if (i > 0 && gap > 0) {
        widgets.add(
          vertical ? SizedBox(height: gap) : SizedBox(width: gap),
        );
      }
      widgets.add(_build(children[i]));
    }

    return widgets;
  }

  Widget _spacer(A2uiComponent node) {
    final width = _toDouble(node.properties['width']);
    final height = _toDouble(node.properties['height']);

    if (width == null && height == null) {
      return const SizedBox(height: AppSpacing.s4);
    }

    return SizedBox(width: width, height: height);
  }

  Widget _text(A2uiComponent node) {
    final text = node.properties['text'] as String? ?? '';
    final variant = node.properties['variant'] as String? ?? 'body';
    final role = node.properties['color'] as String?;

    final style = switch (variant) {
      'headline' => AppTypography.headline,
      'title' => AppTypography.title,
      'caption' => AppTypography.caption,
      'label' => AppTypography.label,
      _ => AppTypography.body,
    };

    return Text(
      text,
      style: role == null
          ? style
          : style.copyWith(color: AppColors.forRole(role)),
    );
  }

  Widget _icon(A2uiComponent node) {
    final iconData = A2uiIcons.resolve(node.properties['icon'] as String?);
    if (iconData == null) return const SizedBox.shrink();

    return AppIcon(
      iconData: iconData,
      size: _toDouble(node.properties['size']) ?? AppSpacing.iconSize,
      color: AppColors.forRole(node.properties['color'] as String?),
    );
  }

  Widget _image(A2uiComponent node) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: Image.network(
        node.properties['src'] as String? ?? '',
        width: _toDouble(node.properties['width']),
        height: _toDouble(node.properties['height']),
        fit: _boxFit(node.properties['fit']),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _card(A2uiComponent node) {
    final role = node.properties['color'] as String?;

    return AppCard(
      color: role == null ? null : AppColors.forRole(role),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _spaced(node, vertical: true),
      ),
    );
  }

  Widget _badge(A2uiComponent node) {
    return AppBadge(
      text: node.properties['text'] as String? ?? '',
      color: AppColors.forRole(node.properties['color'] as String? ?? 'accent'),
      iconData: A2uiIcons.resolve(node.properties['icon'] as String?),
    );
  }

  Widget _listItem(A2uiComponent node) {
    final action = node.action;

    return AppListItem(
      title: node.properties['title'] as String? ?? '',
      subtitle: node.properties['subtitle'] as String?,
      iconData: A2uiIcons.resolve(node.properties['icon'] as String?),
      color: AppColors.forRole(node.properties['color'] as String?),
      onTap: enabled && action != null ? () => _fire(action, 'ListItem') : null,
    );
  }

  Widget _button(A2uiComponent node) {
    final action = node.action;
    final iconData = A2uiIcons.resolve(node.properties['icon'] as String?);

    return AppButton(
      onPressed: enabled && action != null
          ? () => _fire(action, 'AppButton')
          : null,
      text: node.properties['text'] as String? ?? '',
      variant: switch (node.properties['variant']) {
        'primary' => AppButtonVariant.primary,
        'tertiary' => AppButtonVariant.tertiary,
        _ => AppButtonVariant.secondary,
      },
      color: AppColors.forRole(node.properties['color'] as String? ?? 'accent'),
      expand: node.properties['expand'] as bool? ?? false,
      icon: iconData == null ? null : AppIcon(iconData: iconData),
    );
  }

  Widget _iconButton(A2uiComponent node) {
    final action = node.action;
    final iconData = A2uiIcons.resolve(node.properties['icon'] as String?);
    if (iconData == null) return const SizedBox.shrink();

    return Semantics(
      label: node.properties['accessibilityLabel'] as String?,
      button: true,
      child: AppIconButton(
        iconData: iconData,
        onPressed: enabled && action != null
            ? () => _fire(action, 'AppIconButton')
            : () {},
        size: _toDouble(node.properties['size']) ?? AppSpacing.iconSize,
        color: AppColors.forRole(node.properties['color'] as String?),
      ),
    );
  }

  /// Drawn when the server sent a component this build does not know.
  ///
  /// Visible on purpose. It means the app is older than the catalog that
  /// produced the message, and a silent blank would leave that to be noticed
  /// as "the reply looked short".
  Widget _unsupported(A2uiComponent node) {
    log(
      '[A2uiRenderer] unsupported component "${node.component}"',
      name: 'a2ui_renderer',
    );

    return AppBadge(
      text: 'Atualize o app',
      color: AppColors.warning,
      iconData: A2uiIcons.resolve('warning'),
    );
  }

  void _fire(Map<String, dynamic> action, String source) {
    log(
      '[A2uiRenderer] action fired',
      name: 'a2ui_renderer',
      error: {'source': source, 'type': action['type'], 'action': action},
    );
    onAction(action);
  }

  double _gap(Object? value) {
    return switch (value) {
      'none' => 0,
      'tight' => AppSpacing.s2,
      'loose' => AppSpacing.s6,
      _ => AppSpacing.s4,
    };
  }

  MainAxisAlignment _mainAxis(Object? value) {
    return switch (value) {
      'end' => MainAxisAlignment.end,
      'center' => MainAxisAlignment.center,
      'spaceBetween' => MainAxisAlignment.spaceBetween,
      'spaceAround' => MainAxisAlignment.spaceAround,
      'spaceEvenly' => MainAxisAlignment.spaceEvenly,
      _ => MainAxisAlignment.start,
    };
  }

  CrossAxisAlignment _crossAxis(
    Object? value, {
    required CrossAxisAlignment fallback,
  }) {
    return switch (value) {
      'start' => CrossAxisAlignment.start,
      'end' => CrossAxisAlignment.end,
      'center' => CrossAxisAlignment.center,
      'stretch' => CrossAxisAlignment.stretch,
      _ => fallback,
    };
  }

  BoxFit _boxFit(Object? value) {
    return switch (value) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      'fitHeight' => BoxFit.fitHeight,
      'none' => BoxFit.none,
      _ => BoxFit.cover,
    };
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
