import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// {@template api_link_previews}
/// The link cards' previews, as the server read them, kept for the session
/// so a card drawn again draws at once.
///
/// On the web a picture from another site cannot be drawn (CORS), so the
/// server hands it over from the app's own origin.
/// {@endtemplate}
class ApiLinkPreviews implements LinkPreviews {
  /// {@macro api_link_previews}
  ApiLinkPreviews({required this.apiClient, required this.apiBaseUrl});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Where the API lives, which is where the web build's pictures come from.
  final String apiBaseUrl;

  final _known = <String, LinkPreview>{};
  final _reading = <String, Future<LinkPreview>>{};

  @override
  LinkPreview? cached(String url) => _known[url];

  @override
  Future<LinkPreview> fetch(String url) =>
      _reading[url] ??= _read(url).whenComplete(() => _reading.remove(url));

  Future<LinkPreview> _read(String url) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/links/preview',
        queryParameters: {'url': url},
      );
      final data = response.data ?? const <String, dynamic>{};
      final image = data['image'] as String?;
      return _known[url] = LinkPreview(
        url: url,
        title: data['title'] as String?,
        site: data['site'] as String?,
        image: image == null ? null : _drawable(image),
      );
    } on Object {
      // Not kept: the server may answer next time the card is drawn.
      return LinkPreview(url: url);
    }
  }

  String _drawable(String image) => kIsWeb
      ? '$apiBaseUrl/links/image?url=${Uri.encodeQueryComponent(image)}'
      : image;

  @override
  void open(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }
}
