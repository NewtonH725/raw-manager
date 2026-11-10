import 'package:flutter/foundation.dart';

/// Modello immutabile che rappresenta un file .RAF Fujifilm.
@immutable
class RafPhoto {
  final String path;
  final String fileName;
  final bool isCopied;
  final String? exifSummary;
  final bool hasError;
  final String? errorMessage;

  const RafPhoto({
    required this.path,
    required this.fileName,
    this.isCopied = false,
    this.exifSummary,
    this.hasError = false,
    this.errorMessage,
  });

  RafPhoto copyWith({
    String? path,
    String? fileName,
    bool? isCopied,
    String? exifSummary,
    bool? hasError,
    String? errorMessage,
  }) {
    return RafPhoto(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      isCopied: isCopied ?? this.isCopied,
      exifSummary: exifSummary ?? this.exifSummary,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RafPhoto &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          fileName == other.fileName &&
          isCopied == other.isCopied &&
          exifSummary == other.exifSummary &&
          hasError == other.hasError &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      path.hashCode ^
      fileName.hashCode ^
      isCopied.hashCode ^
      (exifSummary?.hashCode ?? 0) ^
      hasError.hashCode ^
      (errorMessage?.hashCode ?? 0);

  @override
  String toString() =>
      'RafPhoto(fileName: $fileName, isCopied: $isCopied, hasError: $hasError)';
}
