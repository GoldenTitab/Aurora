import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/i18n/lang.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

String friendlyError(Object error) {
  if (error is ApiException) return error.message;
  if (error is IOException || error is http.ClientException) {
    return tr('no_internet_connection');
  }
  if (error is TimeoutException) {
    return tr('the_server_took_too_long_to_respond_try_again');
  }
  return tr('something_went_wrong');
}
