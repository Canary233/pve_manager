import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/data/models/pve_resource.dart';
import 'package:pve_manager/data/services/proxmox_api_exception.dart';
import 'package:pve_manager/data/services/proxmox_client.dart';

void main() {
  test(
    'login throws when Proxmox requires two-factor authentication',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api2/json/access/ticket');

        final body = await utf8.decoder.bind(request).join();
        final form = Uri.splitQueryString(body);
        expect(form['username'], 'root@pam');
        expect(form['password'], 'secret');
        expect(form.containsKey('tfa-challenge'), isFalse);

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': {'NeedTFA': 1, 'ticket': 'PVE:tfa-challenge'},
          }),
        );
        await request.response.close();
      });

      final client = ProxmoxClient(
        origin: 'http://${server.address.address}:${server.port}',
        username: 'root',
        password: 'secret',
      );
      addTearDown(client.close);

      final matcher = throwsA(
        isA<ProxmoxTfaRequiredException>().having(
          (error) => error.ticket,
          'ticket',
          'PVE:tfa-challenge',
        ),
      );
      await expectLater(client.login(), matcher);
    },
  );

  test('login detects a ticket challenge even without NeedTFA', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': {
            'ticket': 'PVE:!tfa!challenge',
            'CSRFPreventionToken': 'temporary-token',
          },
        }),
      );
      await request.response.close();
    });

    final client = ProxmoxClient(
      origin: 'http://${server.address.address}:${server.port}',
      username: 'root',
      password: 'secret',
    );
    addTearDown(client.close);

    await expectLater(
      client.login(),
      throwsA(
        isA<ProxmoxTfaRequiredException>().having(
          (error) => error.usesTicketChallenge,
          'usesTicketChallenge',
          isTrue,
        ),
      ),
    );
  });

  test(
    'login answers a tfa challenge and stores the authenticated ticket',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api2/json/access/ticket');

        final body = await utf8.decoder.bind(request).join();
        final form = Uri.splitQueryString(body);
        expect(form['username'], 'alice@pve');
        expect(form['password'], 'totp:123456');
        expect(form['tfa-challenge'], 'PVE:tfa-challenge');

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': {
              'ticket': 'PVE:alice@pve:test',
              'CSRFPreventionToken': 'token',
            },
          }),
        );
        await request.response.close();
      });

      final client = ProxmoxClient(
        origin: 'http://${server.address.address}:${server.port}',
        username: 'alice',
        password: 'secret',
        realm: 'pve',
      );
      addTearDown(client.close);

      await client.login(
        tfaChallenge: ' PVE:tfa-challenge ',
        tfaResponse: ' 123456 ',
      );

      expect(client.hasActiveSession, isTrue);
      expect(client.authCookieValue, 'PVE:alice@pve:test');
    },
  );

  test('login sends prefixed recovery responses unchanged', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final form = Uri.splitQueryString(body);
      expect(form['password'], 'recovery:abcd-efgh');
      expect(form['tfa-challenge'], 'PVE:tfa-challenge');

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': {
            'ticket': 'PVE:alice@pve:test',
            'CSRFPreventionToken': 'token',
          },
        }),
      );
      await request.response.close();
    });

    final client = ProxmoxClient(
      origin: 'http://${server.address.address}:${server.port}',
      username: 'alice',
      password: 'secret',
      realm: 'pve',
    );
    addTearDown(client.close);

    await client.login(
      tfaChallenge: 'PVE:tfa-challenge',
      tfaResponse: 'recovery:abcd-efgh',
    );

    expect(client.hasActiveSession, isTrue);
  });

  test(
    'completeTwoFactor answers ticket challenges through access ticket',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      var requestCount = 0;
      server.listen((request) async {
        requestCount += 1;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api2/json/access/ticket');

        final body = await utf8.decoder.bind(request).join();
        final form = Uri.splitQueryString(body);

        if (requestCount == 1) {
          expect(form['username'], 'root@pam');
          expect(form['password'], 'secret');
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': {
                'NeedTFA': 1,
                'ticket': 'PVE:!tfa!challenge',
                'CSRFPreventionToken': 'temporary-token',
              },
            }),
          );
        } else {
          expect(form['username'], 'root@pam');
          expect(form['password'], 'totp:123456');
          expect(form['tfa-challenge'], 'PVE:!tfa!challenge');
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': {
                'ticket': 'PVE:root@pam:authenticated',
                'CSRFPreventionToken': 'token',
              },
            }),
          );
        }

        await request.response.close();
      });

      final client = ProxmoxClient(
        origin: 'http://${server.address.address}:${server.port}',
        username: 'root',
        password: 'secret',
      );
      addTearDown(client.close);

      try {
        await client.login();
        fail('Expected ProxmoxTfaRequiredException.');
      } on ProxmoxTfaRequiredException catch (challenge) {
        await client.completeTwoFactor(challenge, '123456');
      }

      expect(requestCount, 2);
      expect(client.hasActiveSession, isTrue);
      expect(client.authCookieValue, 'PVE:root@pam:authenticated');
    },
  );

  test(
    'completeTwoFactor uses legacy access tfa with temporary auth',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      var requestCount = 0;
      server.listen((request) async {
        requestCount += 1;

        if (requestCount == 1) {
          expect(request.method, 'POST');
          expect(request.uri.path, '/api2/json/access/ticket');
          final body = await utf8.decoder.bind(request).join();
          final form = Uri.splitQueryString(body);
          expect(form['password'], 'secret');

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': {
                'NeedTFA': 1,
                'ticket': 'PVE:temporary-ticket',
                'CSRFPreventionToken': 'temporary-csrf',
              },
            }),
          );
        } else {
          expect(request.method, 'POST');
          expect(request.uri.path, '/api2/json/access/tfa');
          expect(
            request.headers.value(HttpHeaders.cookieHeader),
            'PVEAuthCookie=PVE:temporary-ticket',
          );
          expect(
            request.headers.value('CSRFPreventionToken'),
            'temporary-csrf',
          );

          final body = await utf8.decoder.bind(request).join();
          final form = Uri.splitQueryString(body);
          expect(form['response'], '123456');

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': {'ticket': 'PVE:root@pam:authenticated'},
            }),
          );
        }

        await request.response.close();
      });

      final client = ProxmoxClient(
        origin: 'http://${server.address.address}:${server.port}',
        username: 'root',
        password: 'secret',
      );
      addTearDown(client.close);

      try {
        await client.login();
        fail('Expected ProxmoxTfaRequiredException.');
      } on ProxmoxTfaRequiredException catch (challenge) {
        expect(challenge.usesTicketChallenge, isFalse);
        await client.completeTwoFactor(challenge, ' 123456 ');
      }

      expect(requestCount, 2);
      expect(client.hasActiveSession, isTrue);
      expect(client.authCookieValue, 'PVE:root@pam:authenticated');
    },
  );

  test('qemu current status uses guest agent fsinfo for disk usage', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;

      switch (request.uri.path) {
        case '/api2/json/access/ticket':
          request.response.write(
            jsonEncode({
              'data': {
                'ticket': 'PVE:root@pam:test',
                'CSRFPreventionToken': 'token',
              },
            }),
          );
        case '/api2/json/nodes/pve/qemu/100/status/current':
          request.response.write(
            jsonEncode({
              'data': {
                'status': 'running',
                'disk': 0,
                'maxdisk': 64 * 1024 * 1024 * 1024,
              },
            }),
          );
        case '/api2/json/nodes/pve/qemu/100/agent/get-fsinfo':
          request.response.write(
            jsonEncode({
              'data': {
                'result': [
                  {
                    'name': '/dev/sda1',
                    'mountpoint': '/',
                    'type': 'ext4',
                    'used-bytes': 12 * 1024 * 1024 * 1024,
                    'total-bytes': 32 * 1024 * 1024 * 1024,
                  },
                  {
                    'name': '/dev/sdb1',
                    'mountpoint': '/data',
                    'type': 'xfs',
                    'used-bytes': 6 * 1024 * 1024 * 1024,
                    'total-bytes': 20 * 1024 * 1024 * 1024,
                  },
                  {
                    'name': 'tmpfs',
                    'mountpoint': '/run',
                    'type': 'tmpfs',
                    'used-bytes': 4 * 1024 * 1024 * 1024,
                    'total-bytes': 4 * 1024 * 1024 * 1024,
                  },
                ],
              },
            }),
          );
        default:
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'message': 'not found'}));
      }

      await request.response.close();
    });

    final client = ProxmoxClient(
      origin: 'http://${server.address.address}:${server.port}',
      username: 'root',
      password: 'secret',
    );
    addTearDown(client.close);

    await client.login();
    final guest = await client.getGuestCurrentStatus(_qemuGuest());

    expect(guest.diskUsed, 18 * 1024 * 1024 * 1024);
    expect(guest.diskTotal, 52 * 1024 * 1024 * 1024);
  });

  test('preloads qemu guest disk usage and applies cached value', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    var fsInfoRequestCount = 0;
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;

      switch (request.uri.path) {
        case '/api2/json/access/ticket':
          request.response.write(
            jsonEncode({
              'data': {
                'ticket': 'PVE:root@pam:test',
                'CSRFPreventionToken': 'token',
              },
            }),
          );
        case '/api2/json/nodes/pve/qemu/100/agent/get-fsinfo':
          fsInfoRequestCount += 1;
          request.response.write(
            jsonEncode({
              'data': {
                'result': [
                  {
                    'name': '/dev/sda1',
                    'mountpoint': '/',
                    'type': 'ext4',
                    'used-bytes': 8 * 1024 * 1024 * 1024,
                    'total-bytes': 24 * 1024 * 1024 * 1024,
                  },
                ],
              },
            }),
          );
        default:
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'message': 'not found'}));
      }

      await request.response.close();
    });

    final client = ProxmoxClient(
      origin: 'http://${server.address.address}:${server.port}',
      username: 'root',
      password: 'secret',
    );
    addTearDown(client.close);

    await client.login();
    await client.preloadGuestDiskUsage([_qemuGuest()]);
    await client.preloadGuestDiskUsage([_qemuGuest()]);

    final guest = client.applyCachedGuestDiskUsage(_qemuGuest());

    expect(fsInfoRequestCount, 1);
    expect(guest.diskUsed, 8 * 1024 * 1024 * 1024);
    expect(guest.diskTotal, 24 * 1024 * 1024 * 1024);
  });

  test(
    'qemu current status keeps api disk usage when guest agent fails',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;

        switch (request.uri.path) {
          case '/api2/json/access/ticket':
            request.response.write(
              jsonEncode({
                'data': {
                  'ticket': 'PVE:root@pam:test',
                  'CSRFPreventionToken': 'token',
                },
              }),
            );
          case '/api2/json/nodes/pve/qemu/100/status/current':
            request.response.write(
              jsonEncode({
                'data': {
                  'status': 'running',
                  'disk': 3 * 1024 * 1024 * 1024,
                  'maxdisk': 64 * 1024 * 1024 * 1024,
                },
              }),
            );
          case '/api2/json/nodes/pve/qemu/100/agent/get-fsinfo':
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write(
              jsonEncode({'message': 'agent not running'}),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(jsonEncode({'message': 'not found'}));
        }

        await request.response.close();
      });

      final client = ProxmoxClient(
        origin: 'http://${server.address.address}:${server.port}',
        username: 'root',
        password: 'secret',
      );
      addTearDown(client.close);

      await client.login();
      final guest = await client.getGuestCurrentStatus(_qemuGuest());

      expect(guest.diskUsed, 3 * 1024 * 1024 * 1024);
      expect(guest.diskTotal, 64 * 1024 * 1024 * 1024);
    },
  );
}

PveResource _qemuGuest() {
  return const PveResource(
    id: 'qemu/100',
    type: 'qemu',
    name: 'Test VM',
    node: 'pve',
    status: 'running',
    cpu: 0,
    memoryUsed: 0,
    memoryTotal: 0,
    diskUsed: 0,
    diskTotal: 0,
    vmid: 100,
  );
}
