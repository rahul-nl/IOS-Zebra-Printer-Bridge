import 'dart:developer' as developer;
import 'package:flutter/services.dart';

import '../models/print_job.dart';

class PrinterService {
  static const MethodChannel _channel = MethodChannel('zsdk');
  
  // Store selected printer info
  String? _selectedSerial;
  String? _selectedName;

  /// Discover bonded/paired Zebra printers via Bluetooth
  Future<List<Map<String, dynamic>>> discoverPrinters() async {
    try {
      developer.log('Discovering Zebra printers...');
      final result = await _channel.invokeMethod('discoverBluetoothDevices');
      final List<dynamic> devices = result ?? [];
      developer.log('Found ${devices.length} Bluetooth device(s)');
      
      return devices.map((d) => Map<String, dynamic>.from(d as Map)).toList();
    } catch (e) {
      developer.log('Error discovering printers: $e');
      throw Exception('Failed to discover printers: $e');
    }
  }

  /// Set the printer to use (serial number for iOS)
  void setPrinter(String serialNumber, String name) {
    _selectedSerial = serialNumber;
    _selectedName = name;
    developer.log('Printer set: $name ($serialNumber)');
  }

  /// Get selected printer info
  String? get selectedSerial => _selectedSerial;
  String? get selectedName => _selectedName;

  /// Print ZPL data via Bluetooth
  Future<PrintResult> printZpl(PrintJob job) async {
    if (_selectedSerial == null) {
      return PrintResult.failure(
        message: 'No printer configured. Please discover and select a printer first.',
        errorCode: 'NO_PRINTER',
        jobId: job.jobId,
      );
    }

    try {
      developer.log('Printing ZPL via Bluetooth to $_selectedSerial');
      developer.log('ZPL Data: ${job.zplData}');

      final result = await _channel.invokeMethod('printZplDataOverBluetooth', {
        'data': job.zplData,
        'macAddress': _selectedSerial,
      });

      developer.log('Print result: $result');

      final response = _parseResponse(result);
      
      if (response['errorCode'] == 'SUCCESS') {
        return PrintResult.success(
          jobId: job.jobId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          printerStatus: response['status']?.toString(),
        );
      } else {
        return PrintResult.failure(
          message: 'Printer error: ${response['message']}',
          errorCode: response['errorCode']?.toString(),
          jobId: job.jobId,
        );
      }
    } catch (e) {
      developer.log('Print error: $e');
      return PrintResult.failure(
        message: 'Print failed: $e',
        errorCode: 'PRINT_EXCEPTION',
        jobId: job.jobId,
      );
    }
  }

  /// Check printer status
  Future<PrintResult> checkPrinterStatus() async {
    if (_selectedSerial == null) {
      return PrintResult.failure(
        message: 'No printer configured',
        errorCode: 'NO_PRINTER',
      );
    }

    try {
      final result = await _channel.invokeMethod('checkPrinterStatusOverBluetooth', {
        'macAddress': _selectedSerial,
      });

      final response = _parseResponse(result);
      
      if (response['errorCode'] == 'SUCCESS') {
        return PrintResult.success(
          jobId: 'status_check',
          printerStatus: response['status']?.toString(),
        );
      } else {
        return PrintResult.failure(
          message: 'Status check failed: ${response['message']}',
          errorCode: response['errorCode']?.toString(),
        );
      }
    } catch (e) {
      return PrintResult.failure(
        message: 'Status check exception: $e',
        errorCode: 'STATUS_EXCEPTION',
      );
    }
  }

  /// Parse response from native SDK
  Map<String, dynamic> _parseResponse(dynamic result) {
    if (result == null) return {'errorCode': 'UNKNOWN'};
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'errorCode': 'UNKNOWN', 'message': result.toString()};
  }
}