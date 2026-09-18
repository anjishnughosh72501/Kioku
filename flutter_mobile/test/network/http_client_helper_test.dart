import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_mobile/core/errors/network_exceptions.dart';
import 'package:flutter_mobile/core/network/http_client_helper.dart';

void main() {
  group('HttpClientHelper', () {
    test('successful GET request returns response without retrying', () async {
      int calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response('{"status":"ok"}', 200);
      });

      final helper = HttpClientHelper(client: mock);
      final resp = await helper.get(Uri.parse('https://api.kioku.app/health'));

      expect(resp.statusCode, 200);
      expect(resp.body, '{"status":"ok"}');
      expect(calls, 1);
    });

    test('GET request retries on 500 error up to maxRetries', () async {
      int calls = 0;
      final mock = MockClient((request) async {
        calls++;
        if (calls < 3) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response('{"status":"recovered"}', 200);
      });

      final helper = HttpClientHelper(client: mock);
      final resp = await helper.get(
        Uri.parse('https://api.kioku.app/test'),
        maxRetries: 2,
      );

      expect(resp.statusCode, 200);
      expect(calls, 3);
    });

    test('POST request does not retry unless retrySafe is true', () async {
      int calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response('Internal Error', 502);
      });

      final helper = HttpClientHelper(client: mock);
      final resp = await helper.post(
        Uri.parse('https://api.kioku.app/action'),
        body: '{"action":"send"}',
      );

      expect(resp.statusCode, 502);
      expect(calls, 1);
    });

    test('TimeoutException is mapped to NetworkException.timeout', () async {
      final mock = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final helper = HttpClientHelper(client: mock);
      expect(
        () => helper.get(
          Uri.parse('https://api.kioku.app/slow'),
          maxRetries: 0,
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.type,
          'type',
          NetworkErrorType.timeout,
        )),
      );
    });

    test('SocketException is mapped to NetworkException.offline', () async {
      final mock = MockClient((request) async {
        throw const SocketException('No route to host');
      });

      final helper = HttpClientHelper(client: mock);
      expect(
        () => helper.get(
          Uri.parse('https://api.kioku.app/offline'),
          maxRetries: 0,
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.type,
          'type',
          NetworkErrorType.offline,
        )),
      );
    });

    test('CancellationToken throws NetworkException.cancelled', () async {
      final token = CancellationToken();
      token.cancel();

      final mock = MockClient((request) async {
        return http.Response('ok', 200);
      });

      final helper = HttpClientHelper(client: mock);
      expect(
        () => helper.get(
          Uri.parse('https://api.kioku.app/cancelled'),
          cancelToken: token,
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.type,
          'type',
          NetworkErrorType.cancelled,
        )),
      );
    });
  });
}
