import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // progress loader if any
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              padding: 20px;
              color: #212121;
              line-height: 1.6;
              background-color: #FAFAFA;
            }
            @media (prefers-color-scheme: dark) {
              body {
                background-color: #121212;
                color: #E0E0E0;
              }
              h2 {
                color: #64B5F6 !important;
              }
              .card {
                background-color: #1E1E1E !important;
                border: 1px solid #333333 !important;
                box-shadow: none !important;
              }
              .header-badge {
                background-color: #1A365D !important;
                color: #90CDF4 !important;
              }
            }
            h1 {
              color: #1A73E8;
              font-size: 24px;
              margin-bottom: 8px;
            }
            h2 {
              color: #1A73E8;
              font-size: 18px;
              margin-top: 24px;
              margin-bottom: 12px;
            }
            p {
              margin-bottom: 16px;
            }
            .card {
              background-color: #FFFFFF;
              padding: 16px;
              border-radius: 12px;
              box-shadow: 0 2px 8px rgba(0,0,0,0.05);
              margin-bottom: 16px;
              border: 1px solid #E0E0E0;
            }
            .header-badge {
              display: inline-block;
              background-color: #E8F0FE;
              color: #1A73E8;
              padding: 6px 12px;
              border-radius: 16px;
              font-size: 12px;
              font-weight: bold;
              margin-bottom: 16px;
            }
          </style>
        </head>
        <body>
          <h1>Privacy Policy</h1>
          <div class="header-badge">On-Device Privacy Promise</div>
          
          <p>Welcome to <strong>Transaction tracker</strong>. We hold your personal privacy and financial confidentiality in the highest regard. This document details how we handle information.</p>

          <div class="card">
            <h2>1. Zero-Telemetry Policy & Storage</h2>
            <p><strong>All transactional data is stored locally.</strong> Your finance logs, budget limits, category setups, and ledger entries are strictly persisted in sandboxed Hive files on your physical device. We maintain no cloud databases, analytics metrics, or server logins.</p>
          </div>

          <div class="card">
            <h2>2. No Analytics & No Advertising</h2>
            <p><strong>We serve zero third-party ads and run zero remote analytics trackers.</strong> Our app operates offline-first, requiring no web telemetry. There are no tracking scripts, user profiling engines, or advertising syndicates inside this application.</p>
          </div>

          <div class="card">
            <h2>3. Secure Local Streams (SMS & Notification Listeners)</h2>
            <p><strong>SMS parsing is strictly performed entirely on-device.</strong> When you grant optional SMS processing permissions to facilitate budget parsing, the message text is scrutinized matching secure regular expressions purely in device memory. Your SMS contents never leave your device.</p>
            <p>The <strong>Notification Listener Service</strong> also processes incoming banking messages instantly in memory on-device and never records, stores, or transmits raw message fields.</p>
          </div>

          <div class="card">
            <h2>4. Your Financial Ownership</h2>
            <p>Because your transaction records reside only under your physical ownership, you can back up, purge, or export your full history at any time using the local Export panel standard layout tools.</p>
          </div>

          <p style="font-size: 11px; color: #888; text-align: center; margin-top: 36px;">
            Transaction tracker App • Version 1.0.0
          </p>
        </body>
        </html>
      ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
