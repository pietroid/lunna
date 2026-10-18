import 'dart:async';

import 'package:app_ui/app_ui.dart';

/// What a link says about itself: its page's title, the site it is on and
/// the picture it offers, as the server read them once and kept them.
class LinkPreview {
  /// Creates a link's preview.
  const LinkPreview({required this.url, this.title, this.site, this.image});

  /// The link as it was written.
  final String url;

  /// The page's title, or null when it has none (or could not be read).
  final String? title;

  /// The site's own name, or null to show the link's host.
  final String? site;

  /// The address of the page's picture, or null when it offers none.
  final String? image;

  /// The host, without `www.`, which stands for the site when it has no name.
  String get host {
    final host = Uri.tryParse(url)?.host ?? url;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

/// {@template link_previews}
/// Where link cards get what they draw, and where they go when tapped.
///
/// The app hands one down with [LinkPreviewScope]; a card with none above it
/// draws its link's host and opens nothing.
/// {@endtemplate}
abstract class LinkPreviews {
  /// The preview already known for [url], so a card read again draws at
  /// once.
  LinkPreview? cached(String url);

  /// Reads [url]'s preview. A link that cannot be read still answers, with
  /// no title and no picture.
  Future<LinkPreview> fetch(String url);

  /// Opens [url] outside the app.
  void open(String url);
}

/// {@template link_preview_scope}
/// Hands [previews] to every link card below it.
/// {@endtemplate}
class LinkPreviewScope extends InheritedWidget {
  /// {@macro link_preview_scope}
  const LinkPreviewScope({
    required this.previews,
    required super.child,
    super.key,
  });

  /// Where the cards below read their previews.
  final LinkPreviews previews;

  /// The previews above [context], if any.
  static LinkPreviews? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LinkPreviewScope>()?.previews;

  @override
  bool updateShouldNotify(LinkPreviewScope oldWidget) =>
      previews != oldWidget.previews;
}

/// {@template app_link_card}
/// A link in the notes, drawn as a card of its own: the page's picture, its
/// title and its site, the whole card one tap from the browser.
///
/// It reads its preview from the [LinkPreviewScope] above it. While it is
/// fetched the picture and the title pulse, under the host, which is known
/// at once; a link with nothing more to say draws itself, for good.
/// [selected] rings it, which is how the notes say the cursor is right after
/// it, where one backspace takes it away.
/// {@endtemplate}
class AppLinkCard extends StatefulWidget {
  /// {@macro app_link_card}
  const AppLinkCard({required this.url, this.selected = false, super.key});

  /// The link.
  final String url;

  /// Whether the cursor is right after the card.
  final bool selected;

  /// How tall the card is, so a page can tell how much room a link takes.
  static const double height = _thumb + 2 * AppSpacing.s3;

  static const _thumb = 64.0;

  @override
  State<AppLinkCard> createState() => _AppLinkCardState();
}

class _AppLinkCardState extends State<AppLinkCard> {
  LinkPreview? _preview;
  LinkPreviews? _previews;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final previews = LinkPreviewScope.maybeOf(context);
    if (previews == _previews) return;
    _previews = previews;
    _read();
  }

  @override
  void didUpdateWidget(AppLinkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _read();
  }

  void _read() {
    final previews = _previews;
    final url = widget.url;
    _preview = previews?.cached(url);
    if (_preview != null || previews == null) return;
    unawaited(
      previews.fetch(url).then((preview) {
        if (mounted && widget.url == url) setState(() => _preview = preview);
      }, onError: (Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final link = preview ?? LinkPreview(url: widget.url);
    final title = preview?.title;
    final loading = preview == null && _previews != null;

    return Semantics(
      link: true,
      label: title ?? link.host,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _previews?.open(widget.url),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: AppLinkCard.height,
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius + 4),
            border: Border.all(
              color: widget.selected ? AppColors.accent : AppColors.fill,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              if (loading)
                const AppSkeleton(
                  width: AppLinkCard._thumb,
                  height: AppLinkCard._thumb,
                  radius: AppSpacing.buttonRadius,
                  onFill: true,
                )
              else
                _Thumb(image: preview?.image),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loading) ...const [
                      AppSkeleton(
                        width: 170,
                        height: AppSpacing.s3,
                        radius: AppSpacing.s1,
                        onFill: true,
                      ),
                      SizedBox(height: AppSpacing.s2),
                      AppSkeleton(
                        width: 110,
                        height: AppSpacing.s3,
                        radius: AppSpacing.s1,
                        onFill: true,
                      ),
                      SizedBox(height: AppSpacing.s1),
                    ] else
                      Text(
                        title ?? widget.url,
                        maxLines: title == null ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: title == null
                            ? AppTypography.label.copyWith(
                                color: AppColors.ink2,
                              )
                            : AppTypography.labelStrong.copyWith(
                                color: AppColors.ink,
                              ),
                      ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      preview?.site ?? link.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              const AppIcon(
                iconData: AppIcons.external,
                size: AppSpacing.s4 + 2,
                color: AppColors.ink3,
              ),
              const SizedBox(width: AppSpacing.s1),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page's picture, squared off; the link icon when it offers none.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    const size = AppLinkCard._thumb;
    const radius = BorderRadius.all(Radius.circular(AppSpacing.buttonRadius));
    const icon = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.fillStrong,
        borderRadius: radius,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: AppIcon(iconData: AppIcons.link, color: AppColors.ink2),
        ),
      ),
    );
    final image = this.image;
    if (image == null) return icon;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => icon,
      ),
    );
  }
}
