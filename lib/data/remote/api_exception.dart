import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

String friendlyError(Object error) {
  if (error is ApiException) return error.message;
  if (error is IOException || error is http.ClientException) {
    return 'اتصال اینترنت برقرار نیست.';
  }
  if (error is TimeoutException) {
    return 'پاسخ سرور دیر رسید. دوباره تلاش کن.';
  }
  return 'خطای غیرمنتظره رخ داد.';
}
