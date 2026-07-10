import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'models/print_job.dart';
import 'services/printer_service.dart';
import 'services/deep_link_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZebraPrinterApp());
}

class ZebraPrinterApp extends StatelessWidget {
  const ZebraPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Zebra Printer Bridge',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: PrinterHomePage(),
    );
  }
}

class PrinterHomePage extends StatefulWidget {
  const PrinterHomePage({super.key});

  @override
  State<PrinterHomePage> createState() => _PrinterHomePageState();
}

class _PrinterHomePageState extends State<PrinterHomePage> {
  final PrinterService _printerService = PrinterService();
  late final DeepLinkHandler _deepLinkHandler;

  List<Map<String, dynamic>> _discoveredPrinters = [];
  Map<String, dynamic>? _selectedPrinter;

  final List<PrintResult> _printHistory = [];
  bool _isLoading = false;
  String _statusMessage = 'Ready';

  @override
  void initState() {
    super.initState();
    _deepLinkHandler = DeepLinkHandler(_printerService);
    _deepLinkHandler.onPrintResult = _onPrintResult;
    _deepLinkHandler.onDevicesDiscovered = _onDevicesDiscovered;
    _deepLinkHandler.initialize();
  }

  void _onPrintResult(PrintResult result) {
    setState(() {
      _printHistory.insert(0, result);
      _statusMessage = result.success
          ? 'Print successful: ${result.jobId}'
          : 'Print failed: ${result.message}';
    });
    HapticFeedback.lightImpact();
  }

  void _onDevicesDiscovered(List<Map<String, dynamic>> devices) {
    setState(() {
      _discoveredPrinters = devices;
    });
  }

  Future<void> _discoverPrinters() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Discovering printers...';
    });

    try {
      final printers = await _printerService.discoverPrinters();
      setState(() {
        _discoveredPrinters = printers;
        _isLoading = false;
        _statusMessage = 'Found ${printers.length} printer(s)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Discovery failed: $e';
      });
    }
  }

  void _selectPrinter(Map<String, dynamic> printer) {
    final serial = printer['serialNumber'] as String? ??
        printer['address'] as String? ??
        printer['macAddress'] as String? ??
        'Unknown';
    final name = printer['friendlyName'] as String? ??
        printer['name'] as String? ??
        'Unknown Printer';

    _printerService.setPrinter(serial, name);
    setState(() {
      _selectedPrinter = printer;
      _statusMessage = 'Selected: $name';
    });
  }

  Future<void> _testPrint() async {
    if (_selectedPrinter == null) {
      setState(() {
        _statusMessage = 'Please select a printer first';
      });
      return;
    }

    const testZpl = '''
^XA
^FO50,50
^A0N,50,50
^FDZebra ZQ620 Test Print^FS
^FO50,120
^B3N,N,100,Y,N
^FD1234567890^FS
^FO50,250
^A0N,30,30
^FDPrinted from Flutter iOS^FS
^XZ
''';

    final job = PrintJob(
      zplData: testZpl,
      jobId: 'test_${DateTime.now().millisecondsSinceEpoch}',
    );

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending to printer...';
    });

    final result = await _printerService.printZpl(job);

    setState(() {
      _isLoading = false;
      _printHistory.insert(0, result);
      _statusMessage = result.success
          ? 'Test print sent successfully'
          : 'Test print failed: ${result.message}';
    });
  }

  Future<void> _checkStatus() async {
    if (_selectedPrinter == null) return;

    setState(() => _isLoading = true);
    final result = await _printerService.checkPrinterStatus();
    setState(() {
      _isLoading = false;
      _statusMessage = 'Status: ${result.printerStatus ?? result.message}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Zebra Printer Bridge'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .navTitleTextStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (_selectedPrinter != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Printer: ${_printerService.selectedName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              CupertinoButton.filled(
                onPressed: _isLoading ? null : _discoverPrinters,
                child: _isLoading
                    ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white)
                    : const Text('Discover Printers'),
              ),

              const SizedBox(height: 8),

              if (_selectedPrinter != null) ...[
                CupertinoButton.filled(
                  onPressed: _isLoading ? null : _testPrint,
                  child: const Text('Send Test Print'),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  color: CupertinoColors.systemGrey,
                  onPressed: _isLoading ? null : _checkStatus,
                  child: const Text('Check Printer Status'),
                ),
                const SizedBox(height: 8),
              ],

              // Discovered Printers List
              if (_discoveredPrinters.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Discovered Printers',
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: _discoveredPrinters.length,
                    itemBuilder: (context, index) {
                      final printer = _discoveredPrinters[index];
                      final serial = printer['serialNumber'] as String? ??
                          printer['address'] as String? ??
                          printer['macAddress'] as String? ??
                          'Unknown';
                      final isSelected = serial == _printerService.selectedSerial;

                      return GestureDetector(
                        onTap: () => _selectPrinter(printer),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CupertinoColors.systemBlue.withAlpha(25)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                    color: CupertinoColors.systemBlue)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.printer,
                                color: isSelected
                                    ? CupertinoColors.systemBlue
                                    : CupertinoColors.systemGrey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      printer['friendlyName'] as String? ??
                                          printer['name'] as String? ??
                                          'Zebra Printer',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'S/N: $serial',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  CupertinoIcons.check_mark_circled_solid,
                                  color: CupertinoColors.systemBlue,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Print History
              if (_printHistory.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Print History',
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: _printHistory.length,
                    itemBuilder: (context, index) {
                      final result = _printHistory[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: result.success
                              ? CupertinoColors.systemGreen.withAlpha(25)
                              : CupertinoColors.systemRed.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              result.success
                                  ? CupertinoIcons.check_mark_circled
                                  : CupertinoIcons.xmark_circle,
                              color: result.success
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result.jobId ?? 'Unknown',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (result.message != null)
                                    Text(
                                      result.message!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}