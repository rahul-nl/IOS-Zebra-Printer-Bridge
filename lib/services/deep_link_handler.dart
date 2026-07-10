import 'dart:convert';
import 'dart:developer' as developer;

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'printer_service.dart';
import '../models/print_job.dart';

class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();
  final PrinterService _printerService;

  Function(PrintResult result)? onPrintResult;
  Function(List<Map<String, dynamic>> devices)? onDevicesDiscovered;

  DeepLinkHandler(this._printerService);

  void initialize() {
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      developer.log('Deep link error: $err');
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    developer.log('Received deep link: $uri');

    if (uri.scheme != 'zebra-print') {
      developer.log('Unknown scheme: ${uri.scheme}');
      return;
    }

    switch (uri.host) {
      case 'print':
        await _handlePrint(uri);
        break;
      case 'discover':
        await _handleDiscover();
        break;
      case 'status':
        await _handleStatus();
        break;
      default:
        developer.log('Unknown host: ${uri.host}');
    }
  }

  Future<void> _handlePrint(Uri uri) async {
    try {
      final zplData = uri.queryParameters['zpl'];
      final jobId = uri.queryParameters['jobId'];
      final copies = int.tryParse(uri.queryParameters['copies'] ?? '1') ?? 1;

      if (zplData == null || zplData.isEmpty) {
        _sendResult(PrintResult.failure(
          message: 'Missing ZPL data in request',
          errorCode: 'MISSING_ZPL',
          jobId: jobId,
        ));
        return;
      }

      final decodedZpl = Uri.decodeComponent(zplData);

      if (_printerService.selectedSerial == null) {
        _sendResult(PrintResult.failure(
          message: 'No printer selected. Open the app and select a printer first.',
          errorCode: 'NO_PRINTER_SELECTED',
          jobId: jobId,
        ));
        return;
      }

      final job = PrintJob(
        zplData: decodedZpl,
        jobId: jobId,
        copies: copies,
      );

      final result = await _printerService.printZpl(job);
      _sendResult(result);

    } catch (e) {
      _sendResult(PrintResult.failure(
        message: 'Failed to process print request: $e',
        errorCode: 'PROCESSING_ERROR',
        jobId: uri.queryParameters['jobId'],
      ));
    }
  }

  Future<void> _handleDiscover() async {
    try {
      final devices = await _printerService.discoverPrinters();
      onDevicesDiscovered?.call(devices);
      _sendResult(PrintResult.success(
        jobId: 'discover',
        printerStatus: jsonEncode(devices),
      ));
    } catch (e) {
      _sendResult(PrintResult.failure(
        message: 'Discovery failed: $e',
        errorCode: 'DISCOVERY_ERROR',
        jobId: 'discover',
      ));
    }
  }

  Future<void> _handleStatus() async {
    final result = await _printerService.checkPrinterStatus();
    _sendResult(result);
  }

  void _sendResult(PrintResult result) {
    developer.log('Print result: ${result.toJson()}');
    onPrintResult?.call(result);

    Clipboard.setData(ClipboardData(
      text: jsonEncode(result.toJson()),
    ));
  }
}