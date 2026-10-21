import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:l10n/l10n.dart';

/// Rows on one fill, split by hairlines, as the sheets of Entregas draw them.
class SheetGroup extends StatelessWidget {
  /// Creates the group.
  const SheetGroup({required this.children, super.key});

  /// The rows.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.s4,
                color: AppColors.line,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One line of a sheet: an icon, what it is, and its value or the control
/// that sets it.
class SheetRow extends StatelessWidget {
  /// Creates the row.
  const SheetRow({
    required this.iconData,
    required this.label,
    this.value,
    this.note,
    this.trailing,
    this.onTap,
    super.key,
  });

  /// What it is about.
  final AppIconData iconData;

  /// What it is.
  final String label;

  /// Its value, as written.
  final String? value;

  /// Where the value comes from, under it.
  final String? note;

  /// The control that sets it, in place of [value].
  final Widget? trailing;

  /// Changes the value in place, when it can be changed here.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: trailing == null ? AppSpacing.s3 + 2 : AppSpacing.s2,
      ),
      child: Row(
        children: [
          AppIcon(
            iconData: iconData,
            size: AppSpacing.s5,
            color: AppColors.ink2,
          ),
          const SizedBox(width: AppSpacing.s3),
          Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing != null
                  // A control too wide for a large text size shrinks rather
                  // than runs off the row.
                  ? FittedBox(fit: BoxFit.scaleDown, child: trailing)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyStrong,
                        ),
                        if (note != null)
                          Text(
                            note!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink3,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Whole reais, typed: "R$" and the number, nothing else.
class MoneyField extends StatelessWidget {
  /// Creates the field.
  const MoneyField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  /// What was typed.
  final TextEditingController controller;

  /// Called on every change.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.end,
        style: AppTypography.bodyStrong,
        cursorColor: AppColors.ink,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration.collapsed(
          hintText: context.l10n.valueOptional,
          hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
        ).copyWith(prefixText: r'R$ '),
      ),
    );
  }
}
