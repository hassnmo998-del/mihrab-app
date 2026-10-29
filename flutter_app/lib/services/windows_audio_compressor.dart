import 'dart:io';
import 'package:flutter/foundation.dart';
import 'telegram_media_resolver.dart';

/// Compresses a recorded WAV into a small AAC (.m4a) on Windows.
///
/// The Windows recorder's AAC encoder can't go below 96kbps (an hour ≈ 43MB, over the
/// archive limit), so on Windows we record plain WAV and transcode it afterwards with
/// the built-in Windows media transcoder — no extra libraries needed. Verified output:
/// AAC mono 16kHz at 32kbps ≈ 14MB per hour.
///
/// The same transcoder compresses a recording that was made elsewhere and picked from
/// a file ([transcode]): any audio Windows can decode (mp3, m4a, wav, wma, flac...), a
/// slice of it at a time so a long lesson is cut into one-hour parts like a live one.
class WindowsAudioCompressor {
  WindowsAudioCompressor._();

  static const String _script = r'''
param([string]$In, [string]$OutDir, [string]$OutName, [int]$Bitrate, [int]$SampleRate, [long]$StartMs = 0, [long]$LengthMs = 0, [switch]$ProbeOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$methods = [System.WindowsRuntimeSystemExtensions].GetMethods()
$asTaskOp = ($methods | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskActP = ($methods | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' })[0]
function AwaitOp($op, [Type]$t) { $task = $asTaskOp.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
function AwaitActP($op, [Type]$p) { $task = $asTaskActP.MakeGenericMethod($p).Invoke($null, @($op)); $task.Wait(-1) | Out-Null }
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.FileProperties.MusicProperties, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime] | Out-Null
function DurationMs($file) {
  try {
    $props = AwaitOp ($file.Properties.GetMusicPropertiesAsync()) ([Windows.Storage.FileProperties.MusicProperties])
    [int64]$props.Duration.TotalMilliseconds
  } catch { 0 }
}
$inFile = AwaitOp ([Windows.Storage.StorageFile]::GetFileFromPathAsync($In)) ([Windows.Storage.StorageFile])
if ($ProbeOnly) { Write-Output ('DURATION_MS=' + (DurationMs $inFile)); exit 0 }
$folder = AwaitOp ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($OutDir)) ([Windows.Storage.StorageFolder])
$outFile = AwaitOp ($folder.CreateFileAsync($OutName, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
$profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateM4a([Windows.Media.MediaProperties.AudioEncodingQuality]::Low)
$profile.Audio.Bitrate = [uint32]$Bitrate
$profile.Audio.SampleRate = [uint32]$SampleRate
$profile.Audio.ChannelCount = [uint32]1
$tr = New-Object Windows.Media.Transcoding.MediaTranscoder
if ($StartMs -gt 0) { $tr.TrimStartTime = [TimeSpan]::FromMilliseconds($StartMs) }
if ($LengthMs -gt 0) { $tr.TrimStopTime = [TimeSpan]::FromMilliseconds($StartMs + $LengthMs) }
$prep = AwaitOp ($tr.PrepareFileTranscodeAsync($inFile, $outFile, $profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
if (-not $prep.CanTranscode) { Write-Error "CannotTranscode: $($prep.FailureReason)"; exit 2 }
AwaitActP ($prep.TranscodeAsync()) ([double])
Write-Output ('DURATION_MS=' + (DurationMs $outFile))
Write-Output 'OK'
''';

  /// Transcodes [wavPath] to a compressed .m4a next to it and deletes the WAV.
  /// Returns the new path, or null if Windows couldn't transcode it (the WAV is kept).
  static Future<String?> compress(String wavPath) async {
    if (kIsWeb || !Platform.isWindows) return wavPath;

    // واجهة ويندوز (StorageFile) ترفض أي مسار فيه «/» أو مسار نسبي، فتفشل معها
    // كل محاولة ضغط: يُوحَّد المسار هنا مهما كان شكل ما وصل.
    final wav = File(wavPath.replaceAll('/', Platform.pathSeparator)).absolute;
    if (!wav.existsSync()) return null;

    final dir = wav.parent.path;
    final baseName = wav.uri.pathSegments.last.replaceAll(RegExp(r'\.wav$', caseSensitive: false), '');
    final outName = '$baseName.m4a';
    final outPath = '$dir${Platform.pathSeparator}$outName';

    final result = await _run(wav.path, dir, outName);
    final out = File(outPath);
    if (result != null && result.exitCode == 0 && out.existsSync() && out.lengthSync() > 0) {
      try {
        await wav.delete();
      } catch (_) {}
      return outPath;
    }
    return null;
  }

  /// Length of an audio file Windows can read, or null if it can't be read as audio.
  static Future<Duration?> probe(String path) async {
    if (kIsWeb || !Platform.isWindows) return null;
    final source = File(path.replaceAll('/', Platform.pathSeparator)).absolute;
    if (!source.existsSync()) return null;

    final result = await _run(source.path, source.parent.path, '', probeOnly: true);
    if (result == null || result.exitCode != 0) return null;
    final ms = _durationMs(result.stdout.toString());
    return ms == null || ms <= 0 ? null : Duration(milliseconds: ms);
  }

  /// Compresses [start] .. [start] + [length] of [input] (the rest of it when [length]
  /// is null) to [output] (.m4a, mono 16kHz at the recording bit rate). The source file is
  /// never touched. Returns the length written, or null if Windows couldn't transcode it
  /// (nothing is left at [output] then).
  static Future<Duration?> transcode(
    String input,
    String output, {
    Duration start = Duration.zero,
    Duration? length,
  }) async {
    if (kIsWeb || !Platform.isWindows) return null;
    final source = File(input.replaceAll('/', Platform.pathSeparator)).absolute;
    if (!source.existsSync()) return null;
    final target = File(output.replaceAll('/', Platform.pathSeparator)).absolute;
    await target.parent.create(recursive: true);

    final result = await _run(
      source.path,
      target.parent.path,
      target.uri.pathSegments.last,
      start: start,
      length: length,
    );
    if (result != null && result.exitCode == 0 && target.existsSync() && target.lengthSync() > 0) {
      final ms = _durationMs(result.stdout.toString());
      return Duration(milliseconds: ms != null && ms > 0 ? ms : (length?.inMilliseconds ?? 0));
    }
    try {
      if (target.existsSync()) await target.delete();
    } catch (_) {}
    return null;
  }

  static int? _durationMs(String stdout) {
    final match = RegExp(r'DURATION_MS=(\d+)').allMatches(stdout).lastOrNull;
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static Future<ProcessResult?> _run(
    String inPath,
    String outDir,
    String outName, {
    Duration start = Duration.zero,
    Duration? length,
    bool probeOnly = false,
  }) async {
    // سكربت لكل استدعاء: ضغطان متتاليان لا يكتب أحدهما فوق سكربت يقرؤه الآخر
    final scriptFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}mihrab_audio_${DateTime.now().microsecondsSinceEpoch}.ps1',
    );
    try {
      await scriptFile.writeAsString(_script);
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        '-In',
        inPath,
        '-OutDir',
        outDir,
        '-OutName',
        outName,
        '-Bitrate',
        '${MediaLimits.recordingBitRate}',
        '-SampleRate',
        '${MediaLimits.recordingSampleRate}',
        '-StartMs',
        '${start.inMilliseconds}',
        '-LengthMs',
        '${length?.inMilliseconds ?? 0}',
        if (probeOnly) '-ProbeOnly',
      ]).timeout(const Duration(minutes: 30));
      if (result.exitCode != 0) {
        debugPrint('⚠️ ضغط التسجيل فشل (${result.exitCode}): ${result.stderr}');
      }
      return result;
    } catch (e) {
      debugPrint('⚠️ ضغط التسجيل فشل: $e');
      return null;
    } finally {
      try {
        await scriptFile.delete();
      } catch (_) {}
    }
  }
}
