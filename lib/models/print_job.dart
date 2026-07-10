class PrintJob {
  final String zplData;
  final String? jobId;
  final int copies;
  final bool checkStatusBeforePrint;

  PrintJob({
    required this.zplData,
    this.jobId,
    this.copies = 1,
    this.checkStatusBeforePrint = false,
  });

  Map<String, dynamic> toJson() => {
        'zplData': zplData,
        'jobId': jobId,
        'copies': copies,
        'checkStatusBeforePrint': checkStatusBeforePrint,
      };

  factory PrintJob.fromJson(Map<String, dynamic> json) => PrintJob(
        zplData: json['zplData'] as String,
        jobId: json['jobId'] as String?,
        copies: json['copies'] as int? ?? 1,
        checkStatusBeforePrint: json['checkStatusBeforePrint'] as bool? ?? false,
      );
}

class PrintResult {
  final bool success;
  final String? message;
  final String? errorCode;
  final String? printerStatus;
  final String? jobId;

  PrintResult({
    required this.success,
    this.message,
    this.errorCode,
    this.printerStatus,
    this.jobId,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        'errorCode': errorCode,
        'printerStatus': printerStatus,
        'jobId': jobId,
      };

  factory PrintResult.success({
    required String jobId,
    String? printerStatus,
  }) =>
      PrintResult(
        success: true,
        jobId: jobId,
        printerStatus: printerStatus,
      );

  factory PrintResult.failure({
    required String message,
    String? errorCode,
    String? jobId,
  }) =>
      PrintResult(
        success: false,
        message: message,
        errorCode: errorCode,
        jobId: jobId,
      );

  PrintResult copyWith({
    bool? success,
    String? message,
    String? errorCode,
    String? printerStatus,
    String? jobId,
  }) =>
      PrintResult(
        success: success ?? this.success,
        message: message ?? this.message,
        errorCode: errorCode ?? this.errorCode,
        printerStatus: printerStatus ?? this.printerStatus,
        jobId: jobId ?? this.jobId,
      );
}