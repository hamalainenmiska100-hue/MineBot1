import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MineBotWebApp());
}

class MineBotWebApp extends StatelessWidget {
  const MineBotWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MineBot',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: kIsWeb ? const MineBotHomePage() : const WebsiteWrapperPage(),
    );
  }
}

class WebsiteWrapperPage extends StatefulWidget {
  const WebsiteWrapperPage({super.key});

  @override
  State<WebsiteWrapperPage> createState() => _WebsiteWrapperPageState();
}

class _WebsiteWrapperPageState extends State<WebsiteWrapperPage> {
  static final Uri _url = Uri.parse('https://hamalainenmiska100-hue.github.io/MineBot1/');
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.host == _url.host) return NavigationDecision.navigate;
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(_url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MineBot')),
      body: WebViewWidget(controller: _controller),
    );
  }
}

enum AppTab { bot, status, settings }
enum ConnectionType { online, offline }

typedef JsonMap = Map<String, dynamic>;

class ServerRecord {
  const ServerRecord({required this.id, required this.ip, required this.port});

  final String id;
  final String ip;
  final int port;

  String get label => '$ip:$port';

  JsonMap toJson() => {'id': id, 'ip': ip, 'port': port};

  static ServerRecord fromJson(JsonMap json) => ServerRecord(
        id: (json['id'] ?? '').toString(),
        ip: (json['ip'] ?? '').toString(),
        port: (json['port'] as num?)?.toInt() ?? 19132,
      );
}

class LinkedAccount {
  const LinkedAccount({required this.id, required this.label, this.createdAt});

  final String id;
  final String label;
  final double? createdAt;
}

class PendingLink {
  const PendingLink({
    required this.status,
    this.verificationUri,
    this.userCode,
    this.accountId,
    this.error,
    this.expiresAt,
  });

  final String status;
  final String? verificationUri;
  final String? userCode;
  final String? accountId;
  final String? error;
  final double? expiresAt;
}

class BotStatus {
  const BotStatus({
    this.sessionId,
    required this.status,
    this.connected,
    this.server,
    this.uptimeMs,
    this.lastConnectedAt,
    this.lastError,
    this.lastDisconnectReason,
    this.connectionType,
  });

  final String? sessionId;
  final String status;
  final bool? connected;
  final String? server;
  final double? uptimeMs;
  final double? lastConnectedAt;
  final String? lastError;
  final String? lastDisconnectReason;
  final String? connectionType;
}

class Health {
  const Health({
    required this.status,
    required this.uptimeSec,
    required this.bots,
    required this.memoryMb,
    required this.maxBots,
  });

  final String status;
  final int uptimeSec;
  final int bots;
  final int memoryMb;
  final int maxBots;
}

class RemoteMaintenance {
  const RemoteMaintenance({
    required this.enabled,
    this.title,
    this.message,
    this.buttonText,
    this.action,
  });

  final bool enabled;
  final String? title;
  final String? message;
  final String? buttonText;
  final String? action;
}

class RemoteAnnouncement {
  const RemoteAnnouncement({
    required this.id,
    required this.type,
    this.title,
    this.message,
    this.actionUrl,
    this.buttonText,
    this.secondaryButtonText,
    required this.showOnce,
    required this.priority,
    this.startsAt,
    this.endsAt,
    this.pollQuestion,
    this.pollOptions = const [],
  });

  final String id;
  final String type;
  final String? title;
  final String? message;
  final String? actionUrl;
  final String? buttonText;
  final String? secondaryButtonText;
  final bool showOnce;
  final int priority;
  final String? startsAt;
  final String? endsAt;
  final String? pollQuestion;
  final List<String> pollOptions;
}

class AppApi {
  static const String baseUrl = 'https://afkbotb.fly.dev';
  static const String announcementsUrl =
      'https://shrill-lab-a34d.kosonenonpaska.workers.dev';

  Future<JsonMap> _request(
    String path, {
    String method = 'GET',
    String? token,
    JsonMap? body,
    bool remote = false,
    String? clientId,
  }) async {
    final url = Uri.parse('${remote ? announcementsUrl : baseUrl}$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    if (clientId != null) headers['X-Client-Id'] = clientId;

    http.Response response;
    if (method == 'POST') {
      headers['Content-Type'] = 'application/json';
      response = await http.post(url, headers: headers, body: jsonEncode(body ?? {}));
    } else {
      response = await http.get(url, headers: headers);
    }

    JsonMap envelope;
    try {
      envelope = jsonDecode(response.body) as JsonMap;
    } catch (_) {
      throw Exception('Invalid server response (${response.statusCode}).');
    }

    if (response.statusCode < 200 || response.statusCode >= 300 || envelope['success'] != true) {
      throw Exception((envelope['error'] ?? 'Request failed.').toString());
    }

    return (envelope['data'] as JsonMap?) ?? <String, dynamic>{};
  }

  Future<String> redeemCode(String code) async {
    final options = [code, code.replaceAll('-', '').trim()].toSet().where((e) => e.isNotEmpty);
    Object? lastErr;
    for (final value in options) {
      try {
        final data = await _request('/auth/redeem', method: 'POST', body: {'code': value});
        final token = (data['token'] ?? data['accessToken'] ?? '').toString();
        if (token.isEmpty) throw Exception('Login response did not include a token.');
        return token;
      } catch (e) {
        lastErr = e;
      }
    }
    throw Exception(lastErr?.toString().replaceFirst('Exception: ', '') ?? 'Login failed.');
  }

  Future<(List<LinkedAccount>, PendingLink?)> fetchAccounts(String token) async {
    final data = await _request('/accounts', token: token);
    final linked = (data['linked'] as List?) ?? [];
    final accounts = linked
        .map((e) => e as JsonMap)
        .map((it) => LinkedAccount(
              id: (it['id'] ?? '').toString(),
              label: (it['label'] ?? '').toString(),
              createdAt: (it['createdAt'] as num?)?.toDouble(),
            ))
        .toList();

    final pendingObj = data['pendingLink'] as JsonMap?;
    final pending = pendingObj == null
        ? null
        : PendingLink(
            status: (pendingObj['status'] ?? '').toString(),
            verificationUri: (pendingObj['verificationUri'] as String?)?.trim().isEmpty == true
                ? null
                : pendingObj['verificationUri'] as String?,
            userCode: pendingObj['userCode'] as String?,
            accountId: pendingObj['accountId'] as String?,
            error: pendingObj['error'] as String?,
            expiresAt: (pendingObj['expiresAt'] as num?)?.toDouble(),
          );

    return (accounts, pending);
  }

  Future<PendingLink> startMicrosoftLink(String token) async {
    final data = await _request('/accounts/link/start', method: 'POST', token: token);
    return PendingLink(
      status: (data['status'] ?? '').toString(),
      verificationUri: data['verificationUri'] as String?,
      userCode: data['userCode'] as String?,
      accountId: data['accountId'] as String?,
    );
  }

  Future<PendingLink> fetchMicrosoftLinkStatus(String token) async {
    final data = await _request('/accounts/link/status', token: token);
    return PendingLink(
      status: (data['status'] ?? '').toString(),
      verificationUri: data['verificationUri'] as String?,
      userCode: data['userCode'] as String?,
      accountId: data['accountId'] as String?,
      error: data['error'] as String?,
      expiresAt: (data['expiresAt'] as num?)?.toDouble(),
    );
  }

  Future<void> unlinkAccount(String token, String accountId) async {
    await _request('/accounts/unlink', method: 'POST', token: token, body: {'accountId': accountId});
  }

  Future<void> startBot(
    String token,
    ServerRecord server,
    ConnectionType connectionType,
    String offlineUsername,
  ) async {
    final body = <String, dynamic>{
      'ip': server.ip,
      'port': server.port,
      'connectionType': connectionType.name,
    };
    if (connectionType == ConnectionType.offline && offlineUsername.trim().isNotEmpty) {
      body['offlineUsername'] = offlineUsername.trim();
    }
    await _request('/bots/start', method: 'POST', token: token, body: body);
  }

  Future<void> stopBot(String token) async {
    await _request('/bots/stop', method: 'POST', token: token);
  }

  Future<void> reconnectBot(String token) async {
    await _request('/bots/reconnect', method: 'POST', token: token);
  }

  Future<void> logout(String token) async {
    await _request('/auth/logout', method: 'POST', token: token);
  }

  Future<BotStatus> fetchBotStatus(String token) async {
    final data = await _request('/bots', token: token);
    return BotStatus(
      sessionId: data['sessionId'] as String?,
      status: (data['status'] ?? 'offline').toString(),
      connected: data['connected'] as bool?,
      server: data['server'] as String?,
      uptimeMs: (data['uptimeMs'] as num?)?.toDouble(),
      lastConnectedAt: (data['lastConnectedAt'] as num?)?.toDouble(),
      lastError: data['lastError'] as String?,
      lastDisconnectReason: data['lastDisconnectReason'] as String?,
      connectionType: data['connectionType'] as String?,
    );
  }

  Future<Health> fetchHealth() async {
    final data = await _request('/health');
    return Health(
      status: (data['status'] ?? '').toString(),
      uptimeSec: (data['uptimeSec'] as num?)?.toInt() ?? 0,
      bots: (data['bots'] as num?)?.toInt() ?? 0,
      memoryMb: (data['memoryMb'] as num?)?.toInt() ?? 0,
      maxBots: (data['maxBots'] as num?)?.toInt() ?? 0,
    );
  }

  Future<(RemoteMaintenance?, RemoteAnnouncement?)> fetchBootstrap(String clientId) async {
    final data = await _request('/api/bootstrap', remote: true, clientId: clientId);
    final maintenanceObj = data['maintenance'] as JsonMap?;
    final maintenance = maintenanceObj == null
        ? null
        : RemoteMaintenance(
            enabled: maintenanceObj['enabled'] == true,
            title: maintenanceObj['title'] as String?,
            message: maintenanceObj['message'] as String?,
            buttonText: maintenanceObj['buttonText'] as String?,
            action: maintenanceObj['action'] as String?,
          );

    final now = DateTime.now().toUtc();
    final items = ((data['items'] as List?) ?? [])
        .map((e) => e as JsonMap)
        .map((it) {
          final poll = it['poll'] as JsonMap?;
          return RemoteAnnouncement(
            id: (it['id'] ?? const Uuid().v4()).toString(),
            type: (it['type'] ?? 'announcement').toString(),
            title: it['title'] as String?,
            message: it['message'] as String?,
            actionUrl: it['actionUrl'] as String?,
            buttonText: it['buttonText'] as String?,
            secondaryButtonText: it['secondaryButtonText'] as String?,
            showOnce: it['showOnce'] == true,
            priority: (it['priority'] as num?)?.toInt() ?? 0,
            startsAt: it['startsAt'] as String?,
            endsAt: it['endsAt'] as String?,
            pollQuestion: poll?['question'] as String?,
            pollOptions: ((poll?['options'] as List?) ?? []).map((e) => e.toString()).toList(),
          );
        })
        .where((item) {
          final startsAt = item.startsAt;
          if (startsAt != null) {
            final start = DateTime.tryParse(startsAt)?.toUtc();
            if (start != null && start.isAfter(now)) return false;
          }
          final endsAt = item.endsAt;
          if (endsAt != null) {
            final end = DateTime.tryParse(endsAt)?.toUtc();
            if (end != null && end.isBefore(now)) return false;
          }
          return true;
        })
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    return (
      maintenance?.enabled == true ? maintenance : null,
      items.isEmpty ? null : items.first,
    );
  }
}

class MineBotHomePage extends StatefulWidget {
  const MineBotHomePage({super.key});

  @override
  State<MineBotHomePage> createState() => _MineBotHomePageState();
}

class _MineBotHomePageState extends State<MineBotHomePage> {
  final _api = AppApi();
  final _uuid = const Uuid();

  bool tutorialSeen = false;
  bool isLoggedIn = false;
  bool isBusy = false;
  String codeInput = '';
  String? token;

  List<ServerRecord> servers = [];
  String selectedServerId = '';
  ConnectionType connectionType = ConnectionType.online;
  String offlineUsername = '';

  List<LinkedAccount> linkedAccounts = [];
  PendingLink? pendingLink;
  BotStatus? botStatus;
  Health? health;
  int? serverLatencyMs;

  RemoteMaintenance? maintenance;
  RemoteAnnouncement? announcement;

  AppTab selectedTab = AppTab.bot;
  String remoteClientId = '';

  final _loginController = TextEditingController();
  final _offlineNameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '19132');

  @override
  void initState() {
    super.initState();
    _bootstrapApp();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _offlineNameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapApp() async {
    final prefs = await SharedPreferences.getInstance();
    tutorialSeen = prefs.getBool('tutorial_seen') ?? false;
    token = prefs.getString('token');
    isLoggedIn = token?.isNotEmpty == true;

    remoteClientId = prefs.getString('remote_client_id') ?? _uuid.v4();
    await prefs.setString('remote_client_id', remoteClientId);

    final serversPayload = prefs.getString('servers');
    if (serversPayload != null && serversPayload.isNotEmpty) {
      final decoded = (jsonDecode(serversPayload) as List).cast<JsonMap>();
      servers = decoded.map(ServerRecord.fromJson).toList();
    }
    selectedServerId = prefs.getString('selected_server_id') ?? '';
    if (selectedServerId.isEmpty && servers.isNotEmpty) {
      selectedServerId = servers.first.id;
    }

    setState(() {});

    if (isLoggedIn) {
      await refreshAll();
    }
    await refreshBootstrap(silent: true);
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('servers', jsonEncode(servers.map((s) => s.toJson()).toList()));
    await prefs.setString('selected_server_id', selectedServerId);
  }

  Future<void> _saveToken(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove('token');
    } else {
      await prefs.setString('token', value);
    }
  }

  Future<void> finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_seen', true);
    setState(() => tutorialSeen = true);
  }

  void updateCode(String input) {
    final clean = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    setState(() {
      codeInput = clean.length > 32 ? clean.substring(0, 32) : clean;
      _loginController.value = TextEditingValue(
        text: codeInput,
        selection: TextSelection.collapsed(offset: codeInput.length),
      );
    });
  }

  Future<void> login() async {
    final code = codeInput.trim().toUpperCase();
    final compact = code.replaceAll('-', '');
    if (compact.length < 10) {
      _snack('Please enter a valid access code.');
      return;
    }

    await _withBusy(() async {
      try {
        token = await _api.redeemCode(code);
        await _saveToken(token);
        setState(() {
          isLoggedIn = true;
          codeInput = '';
          _loginController.clear();
        });
        _snack('Login successful.');
        await refreshAll();
      } catch (e) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    });
  }

  Future<void> logout() async {
    await _withBusy(() async {
      final auth = token;
      if (auth != null) {
        try {
          await _api.logout(auth);
        } catch (_) {}
      }
      token = null;
      await _saveToken(null);
      setState(() {
        isLoggedIn = false;
        selectedTab = AppTab.bot;
        linkedAccounts = [];
        pendingLink = null;
        botStatus = null;
        health = null;
      });
      _snack('Signed out.');
    });
  }

  Future<void> refreshAll() async {
    final auth = token;
    if (auth == null) return;
    await Future.wait([refreshBotStatus(auth), refreshHealth(), refreshAccounts(auth)]);
  }

  Future<void> refreshAccounts(String auth) async {
    try {
      final (accounts, pending) = await _api.fetchAccounts(auth);
      setState(() {
        linkedAccounts = accounts;
        pendingLink = pending;
      });
    } catch (_) {}
  }

  Future<void> refreshHealth() async {
    final started = DateTime.now();
    try {
      final nextHealth = await _api.fetchHealth();
      final latency = DateTime.now().difference(started).inMilliseconds;
      setState(() {
        health = nextHealth;
        serverLatencyMs = latency == 0 ? 1 : latency;
      });
    } catch (_) {}
  }

  Future<void> refreshBotStatus(String auth) async {
    try {
      final nextStatus = await _api.fetchBotStatus(auth);
      setState(() => botStatus = nextStatus);
    } catch (_) {}
  }

  Future<void> beginMicrosoftLink() async {
    final auth = token;
    if (auth == null) return;
    await _withBusy(() async {
      try {
        final link = await _api.startMicrosoftLink(auth);
        setState(() => pendingLink = link);
        _snack('Microsoft login started.');
      } catch (e) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    });
  }

  Future<void> refreshMicrosoftLinkStatus() async {
    final auth = token;
    if (auth == null) return;
    try {
      final link = await _api.fetchMicrosoftLinkStatus(auth);
      setState(() => pendingLink = link);
      if (link.status == 'success') {
        await refreshAccounts(auth);
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> unlinkFirstAccount() async {
    final auth = token;
    final account = linkedAccounts.isEmpty ? null : linkedAccounts.first;
    if (auth == null || account == null) return;

    await _withBusy(() async {
      try {
        await _api.unlinkAccount(auth, account.id);
        _snack('Account unlinked.');
        await refreshAccounts(auth);
      } catch (e) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    });
  }

  Future<void> addServer(String ip, int port) async {
    if (ip.trim().isEmpty) {
      _snack('Please enter an IP address.');
      return;
    }
    setState(() {
      servers = [...servers, ServerRecord(id: _uuid.v4(), ip: ip.trim(), port: port)];
      selectedServerId = selectedServerId.isEmpty ? servers.first.id : selectedServerId;
      _ipController.clear();
    });
    await _saveServers();
    _snack('Server added.');
  }

  Future<void> removeServer(String id) async {
    setState(() {
      servers = servers.where((s) => s.id != id).toList();
      if (selectedServerId == id) {
        selectedServerId = servers.isEmpty ? '' : servers.first.id;
      }
    });
    await _saveServers();
  }

  Future<void> selectServer(String id) async {
    setState(() => selectedServerId = id);
    await _saveServers();
  }

  Future<void> startBot() async {
    final auth = token;
    if (auth == null) return;
    final server = servers.where((s) => s.id == selectedServerId).firstOrNull;
    if (server == null) {
      setState(() => selectedTab = AppTab.settings);
      _snack('Add a server first in Settings.');
      return;
    }
    if (connectionType == ConnectionType.online && linkedAccounts.isEmpty) {
      _snack('Link a Microsoft account first.');
      return;
    }

    await _withBusy(() async {
      try {
        await _api.startBot(auth, server, connectionType, offlineUsername);
        _snack('Bot starting...');
        await refreshAll();
      } catch (e) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    });
  }

  Future<void> stopBot() => _doBotAction('Bot stopped.', (auth) => _api.stopBot(auth));

  Future<void> reconnectBot() =>
      _doBotAction('Reconnect requested.', (auth) => _api.reconnectBot(auth));

  Future<void> _doBotAction(
    String message,
    Future<void> Function(String auth) action,
  ) async {
    final auth = token;
    if (auth == null) return;
    await _withBusy(() async {
      try {
        await action(auth);
        _snack(message);
        await refreshAll();
      } catch (e) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    });
  }

  Future<void> refreshBootstrap({bool silent = false}) async {
    try {
      final (nextMaintenance, nextAnnouncement) = await _api.fetchBootstrap(remoteClientId);
      setState(() {
        maintenance = nextMaintenance;
        announcement = nextAnnouncement;
      });
    } catch (_) {
      if (!silent) _snack('Announcement sync failed.');
    }
  }

  Future<void> openUrlString(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _withBusy(Future<void> Function() block) async {
    setState(() => isBusy = true);
    await block();
    if (mounted) {
      setState(() => isBusy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String formatUptime(double? uptimeMs) {
    if (uptimeMs == null) return '-';
    final seconds = (uptimeMs / 1000).floor();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  String formatServerTime(double? value) {
    if (value == null) return '-';
    final millis = value > 10000000000 ? value.toInt() : (value * 1000).toInt();
    return DateFormat('MMM d, yyyy h:mm a').format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  @override
  Widget build(BuildContext context) {
    final selected = servers.where((s) => s.id == selectedServerId).firstOrNull;
    final status = botStatus?.status.toLowerCase() ?? 'offline';
    final isBotRunning = <String>{'connected', 'starting', 'reconnecting', 'disconnected'}.contains(status) ||
        botStatus?.connected == true;

    return Scaffold(
      appBar: AppBar(title: const Text('MineBot')),
      bottomNavigationBar: tutorialSeen && isLoggedIn
          ? NavigationBar(
              selectedIndex: selectedTab.index,
              onDestinationSelected: (idx) => setState(() => selectedTab = AppTab.values[idx]),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.smart_toy), label: 'Bot'),
                NavigationDestination(icon: Icon(Icons.monitor_heart), label: 'Status'),
                NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
              ],
            )
          : null,
      body: Builder(
        builder: (context) {
          if (!tutorialSeen) return _tutorialView();
          if (!isLoggedIn) return _loginView();
          if (selectedTab == AppTab.bot) return _botView(selected, isBotRunning);
          if (selectedTab == AppTab.status) return _statusView();
          return _settingsView();
        },
      ),
    );
  }

  Widget _tutorialView() {
    return _pageShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome to MineBot', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Manage your bot, servers, linked accounts, and live status from the web client.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: finishTutorial, child: const Text('Get Started')),
          ],
        ),
      ),
    );
  }

  Widget _loginView() {
    return _pageShell(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('MineBot', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Sign in with your access code to control your bot.'),
              const SizedBox(height: 18),
              TextField(
                controller: _loginController,
                decoration: const InputDecoration(
                  labelText: 'Access code',
                  hintText: 'XXXX-XXXX-XXXX',
                  helperText: 'Dashes are optional.',
                  border: OutlineInputBorder(),
                ),
                onChanged: updateCode,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: isBusy ? null : login,
                  child: Text(isBusy ? 'Signing in...' : 'Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botView(ServerRecord? selected, bool isBotRunning) {
    final statusCard = Card(
          child: ListTile(
            title: const Text('Bot'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${botStatus?.status ?? 'offline'}'),
                Text('Server: ${botStatus?.server ?? selected?.label ?? 'Not selected'}'),
                Text('Latency: ${serverLatencyMs == null ? '-' : '$serverLatencyMs ms'}'),
              ],
            ),
          ),
        );

    final connectionCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Online'),
                      selected: connectionType == ConnectionType.online,
                      onSelected: (_) => setState(() => connectionType = ConnectionType.online),
                    ),
                    ChoiceChip(
                      label: const Text('Offline'),
                      selected: connectionType == ConnectionType.offline,
                      onSelected: (_) => setState(() => connectionType = ConnectionType.offline),
                    ),
                  ],
                ),
                if (connectionType == ConnectionType.offline) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _offlineNameController,
                    onChanged: (value) => setState(() => offlineUsername = value),
                    decoration: const InputDecoration(
                      labelText: 'Offline Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

    final accountCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Microsoft Account', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (pendingLink != null && (pendingLink!.status == 'starting' || pendingLink!.status == 'pending')) ...[
                  Text('Code: ${pendingLink!.userCode ?? '-'}'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    ElevatedButton(
                      onPressed: pendingLink?.verificationUri == null
                          ? null
                          : () => openUrlString(pendingLink!.verificationUri!),
                      child: const Text('Open Link'),
                    ),
                    OutlinedButton(onPressed: refreshMicrosoftLinkStatus, child: const Text('Refresh')),
                  ])
                ] else if (linkedAccounts.isNotEmpty) ...[
                  Text('Linked: ${linkedAccounts.first.label}'),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: unlinkFirstAccount, child: const Text('Unlink Account')),
                ] else ...[
                  ElevatedButton(onPressed: beginMicrosoftLink, child: const Text('Link Microsoft Account')),
                ],
              ],
            ),
          ),
        );

    final actionsCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (isBotRunning) ...[
                  ElevatedButton(onPressed: stopBot, child: const Text('Stop Bot')),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(onPressed: reconnectBot, child: const Text('Reconnect')),
                    OutlinedButton(onPressed: refreshAll, child: const Text('Refresh')),
                  ]),
                ] else ...[
                  ElevatedButton(
                    onPressed: isBusy ? null : startBot,
                    child: Text(isBusy ? 'Working...' : 'Start Bot'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(onPressed: refreshAll, child: const Text('Refresh')),
                    OutlinedButton(
                      onPressed: () => setState(() => selectedTab = AppTab.settings),
                      child: const Text('Settings'),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        );

    final maintenanceCard = maintenance == null
        ? null
        : Card(
            color: Colors.orange.shade50,
            child: ListTile(
              title: Text(maintenance!.title ?? 'Maintenance'),
              subtitle: Text(maintenance!.message ?? 'Uh oh.. Maintenance Time!'),
            ),
          );

    final announcementCard = announcement == null
        ? null
        : Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(announcement!.title ?? 'Announcement', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(announcement!.message ?? 'Something new just dropped.'),
                  if (announcement!.pollQuestion != null) ...[
                    const SizedBox(height: 8),
                    Text(announcement!.pollQuestion!),
                  ],
                  if (announcement!.pollOptions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: announcement!.pollOptions
                          .map((opt) => OutlinedButton(
                                onPressed: () => setState(() => announcement = null),
                                child: Text(opt),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    if (announcement!.actionUrl != null)
                      ElevatedButton(
                        onPressed: () async {
                          await openUrlString(announcement!.actionUrl!);
                          setState(() => announcement = null);
                        },
                        child: Text(announcement!.buttonText ?? 'OK'),
                      ),
                    OutlinedButton(
                      onPressed: () => setState(() => announcement = null),
                      child: Text(announcement!.secondaryButtonText ?? 'Later'),
                    )
                  ]),
                ],
              ),
            ),
          );

    return _pageShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final left = [
            statusCard,
            const SizedBox(height: 12),
            connectionCard,
            const SizedBox(height: 12),
            accountCard,
          ];
          final right = [
            actionsCard,
            if (maintenanceCard != null) ...[const SizedBox(height: 12), maintenanceCard],
            if (announcementCard != null) ...[const SizedBox(height: 12), announcementCard],
          ];

          if (!wide) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [...left, const SizedBox(height: 12), ...right],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: left,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: right,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusView() {
    final cards = [
      Card(
          child: ListTile(
            title: const Text('Status'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session: ${botStatus?.status ?? 'offline'}'),
                Text('Uptime: ${formatUptime(botStatus?.uptimeMs)}'),
                Text('Last connected: ${formatServerTime(botStatus?.lastConnectedAt)}'),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      Card(
          child: ListTile(
            title: const Text('Server Metrics'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Latency: ${serverLatencyMs == null ? '-' : '$serverLatencyMs ms'}'),
                Text('Memory: ${health?.memoryMb == null ? '-' : '${health!.memoryMb} MB'}'),
                Text('Global Memory: ${health?.memoryMb ?? '-'} / 512 MB'),
                Text('Active Bots: ${health?.bots ?? '-'} / ${health?.maxBots ?? '-'}'),
              ],
            ),
          ),
        ),
    ];

    return _pageShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return ListView(padding: const EdgeInsets.all(16), children: cards);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [cards[0]])),
              const SizedBox(width: 12),
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [cards[2]])),
            ],
          );
        },
      ),
    );
  }

  Widget _settingsView() {
    final serversCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Servers', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...servers.map(
                  (server) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(server.ip, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Port ${server.port}'),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => selectServer(server.id),
                          child: Text(selectedServerId == server.id ? 'Selected' : 'Select'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () => removeServer(server.id), child: const Text('Delete')),
                      ],
                    ),
                  ),
                ),
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (clean != value) {
                      _portController.value = TextEditingValue(
                        text: clean,
                        selection: TextSelection.collapsed(offset: clean.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => addServer(_ipController.text, int.tryParse(_portController.text) ?? 19132),
                  child: const Text('Add Server'),
                ),
              ],
            ),
          ),
        );
    final communityCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Community', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => openUrlString('https://discord.gg/CNZsQDBYvw'),
                  child: const Text('Join our Discord'),
                ),
                OutlinedButton(onPressed: logout, child: const Text('Sign Out')),
              ],
            ),
          ),
        );

    return _pageShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 980) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [serversCard, const SizedBox(height: 12), communityCard],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [serversCard])),
              const SizedBox(width: 12),
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [communityCard])),
            ],
          );
        },
      ),
    );
  }

  Widget _pageShell({required Widget child}) {
    return Container(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: child,
      ),
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
