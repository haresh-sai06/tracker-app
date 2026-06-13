import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:tracker_app/core/services/sms_parser_service.dart';
import 'package:tracker_app/data/services/database_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class ScannedEmailLog {
  final String sender;
  final String date;
  final String subject;
  final String parsedResult;

  ScannedEmailLog({
    required this.sender,
    required this.date,
    required this.subject,
    required this.parsedResult,
  });

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'date': date,
      'subject': subject,
      'parsedResult': parsedResult,
    };
  }

  factory ScannedEmailLog.fromJson(Map<String, dynamic> json) {
    return ScannedEmailLog(
      sender: json['sender'] ?? 'Unknown Sender',
      date: json['date'] ?? '',
      subject: json['subject'] ?? '(No Subject)',
      parsedResult: json['parsedResult'] ?? 'Unknown',
    );
  }
}

class GmailSyncService {
  static final List<String> defaultSenders = [
    'alerts@hdfcbank.net',
    'alerts@icicibank.com',
    'alerts@hsbc.com',
    'alerts@axisbank.com',
    'alerts@sbi.co.in'
  ];

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      gmail.GmailApi.gmailReadonlyScope,
    ],
  );

  static GoogleSignIn get googleSignIn => _googleSignIn;
  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Performs Google Sign-In with Gmail readonly scope
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      // First try silent sign-in
      final silentUser = await _googleSignIn.signInSilently();
      if (silentUser != null) return silentUser;
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('Gmail OAuth Sign In Failed: $e');
      rethrow;
    }
  }

  /// Get currently signed-in Google account without prompting UI
  static Future<GoogleSignInAccount?> getConnectedAccount() async {
    return await _googleSignIn.signInSilently();
  }

  /// Revokes active OAuth token and signs out, clearing all device-specific Gmail history
  static Future<void> disconnectGmail() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    // Delete log records from settings panel box
    await DatabaseService.settingsBox.delete('gmail_last_sync_time');
    await DatabaseService.settingsBox.delete('gmail_last_sync_tx_count');
    await DatabaseService.settingsBox.delete('gmail_scanned_emails');
  }

  /// Syncs matching bank alerts from the user's Gmail box, parsing transactions dynamically.
  static Future<List<ParsedTransaction>> syncTransactions() async {
    final account = await signIn();
    if (account == null) {
      throw Exception('Authorization was declined or canceled by the user.');
    }

    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    final gmailApi = gmail.GmailApi(client);

    // Retrieve custom sender domains
    final List<String> senders = List<String>.from(
      DatabaseService.settingsBox.get('gmail_sender_domains', defaultValue: defaultSenders)
    );

    if (senders.isEmpty) {
      throw Exception('Gmail Sync configuration error: No sender domains or bank alerts are added.');
    }

    // Build query to minimize inbox reading API overhead
    final query = 'from:(${senders.join(" OR ")}) newer_than:30d';
    
    final response = await gmailApi.users.messages.list("me", q: query, maxResults: 40);
    final messages = response.messages ?? [];

    final List<ParsedTransaction> newlyParsedTxs = [];
    final List<ScannedEmailLog> scannedLogs = [];

    for (final msg in messages) {
      if (msg.id == null) continue;

      try {
        final fullMsg = await gmailApi.users.messages.get("me", msg.id!, format: 'full');
        final sender = _getHeaderValue(fullMsg, 'from');
        final dateHeader = _getHeaderValue(fullMsg, 'date');
        final subject = _getHeaderValue(fullMsg, 'subject');
        
        final bodyText = _extractMessageBody(fullMsg);
        if (bodyText.trim().isEmpty) {
          scannedLogs.add(ScannedEmailLog(
            sender: sender,
            date: dateHeader,
            subject: subject,
            parsedResult: 'Empty message body',
          ));
          continue;
        }

        // Call our core SMS pattern matching service to scan the transaction
        final parsedTx = await SmsParserService.parseSms(bodyText);

        if (parsedTx != null) {
          newlyParsedTxs.add(parsedTx);
          scannedLogs.add(ScannedEmailLog(
            sender: sender,
            date: dateHeader,
            subject: subject,
            parsedResult: 'Matched Alert: \$${parsedTx.amount.toStringAsFixed(2)} (${parsedTx.type.name})',
          ));
        } else {
          scannedLogs.add(ScannedEmailLog(
            sender: sender,
            date: dateHeader,
            subject: subject,
            parsedResult: 'Did not match bank transaction regex patterns',
          ));
        }
      } catch (e) {
        debugPrint('Failed to fetch details for message ${msg.id}: $e');
      }
    }

    // Update synchronization metadata securely on-device
    final nowString = DateTime.now().toIso8601String();
    await DatabaseService.settingsBox.put('gmail_last_sync_time', nowString);
    await DatabaseService.settingsBox.put('gmail_last_sync_tx_count', newlyParsedTxs.length);
    
    final jsonLogs = scannedLogs.map((log) => log.toJson()).toList();
    await DatabaseService.settingsBox.put('gmail_scanned_emails', jsonLogs);

    return newlyParsedTxs;
  }

  static String _getHeaderValue(gmail.Message message, String name) {
    final headers = message.payload?.headers;
    if (headers == null) return '';
    final header = headers.firstWhere(
      (h) => h.name?.toLowerCase() == name.toLowerCase(),
      orElse: () => gmail.MessagePartHeader(),
    );
    return header.value ?? '';
  }

  static String _extractMessageBody(gmail.Message message) {
    final payload = message.payload;
    if (payload == null) return '';

    if (payload.mimeType == 'text/plain' && payload.body?.data != null) {
      return _decodeBase64(payload.body!.data!);
    }

    final parts = payload.parts;
    if (parts != null && parts.isNotEmpty) {
      return _extractBodyFromParts(parts);
    }

    return '';
  }

  static String _extractBodyFromParts(List<gmail.MessagePart> parts) {
    for (final part in parts) {
      if (part.mimeType == 'text/plain' && part.body?.data != null) {
        return _decodeBase64(part.body!.data!);
      }
      if (part.parts != null && part.parts!.isNotEmpty) {
        final body = _extractBodyFromParts(part.parts!);
        if (body.isNotEmpty) return body;
      }
    }
    // Fallback to text/html
    for (final part in parts) {
      if (part.mimeType == 'text/html' && part.body?.data != null) {
        return _decodeBase64(part.body!.data!);
      }
    }
    return '';
  }

  static String _decodeBase64(String encoded) {
    try {
      var normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      return '';
    }
  }
}
