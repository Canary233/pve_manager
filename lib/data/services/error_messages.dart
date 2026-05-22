import 'dart:io';

import 'package:pve_manager/data/services/proxmox_api_exception.dart';

ProxmoxApiException nonJsonResponseException(
  Uri uri,
  HttpClientResponse response,
  String content,
) {
  final contentType =
      response.headers.contentType?.toString() ??
      response.headers.value(HttpHeaders.contentTypeHeader) ??
      'unknown';
  final preview = responsePreview(content);

  return ProxmoxApiException(
    ProxmoxErrorCode.nonJsonResponse,
    values: {
      'uri': uri,
      'statusCode': response.statusCode,
      'contentType': contentType,
      'preview': preview,
    },
  );
}

String? responsePreview(String content) {
  final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized.length > 180
      ? '${normalized.substring(0, 180)}...'
      : normalized;
}
