import 'dart:io';
import 'package:flutter/foundation.dart';
import 'telegram_media_resolver.dart';

/// Compresses a recorded WAV into a small AAC (.m4a) on Windows.
///
/// The Windows recorder's AAC encoder can't go below 96kbps (an hour ≈ 43MB, over the
/// archive limit), so on Windows we record plain WAV and transcode it afterwards with
/// the built-in Windows media transcoder — no extra libraries needed. Verified output:
/// AAC mono 16kHz at 32kbps ≈ 14MB per hour.
class WindowsAudioCompressor {
  WindowsAudioCompressor._();

  static const String _script = r'''
param([string]$In, [string]$OutDir, [string]$OutName, [int]$Bitrate, [int]$SampleRate)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$methods = [System.WindowsRuntimeSystemExtensions].GetMethods()
$asTaskOp = ($methods | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskActP = ($methods | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' })[0]
function AwaitOp($op, [Type]$t) { $task = $asTaskOp.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
function AwaitActP($op, [Type]$p) { $task = $asTaskActP.MakeGenericMethod($p).Invoke($null, @($op)); $task.Wait(-1) | Out-Null }
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime] | Out-Null
$inFile = AwaitOp ([Windows.Storage.StorageFile]::GetFileFromPathAsync($In)) ([Windows.Storage.StorageFile])
$folder = AwaitOp ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($OutDir)) ([Windows.Storage.StorageFolder])
$outFile = AwaitOp ($folder.CreateFileAsync($OutName, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
$profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateM4a([Windows.Media.MediaProperties.AudioEncodingQuality]::Low)
$profile.Audio.Bitrate = [uint32]$Bitrate
$profile.Audio.SampleRate = [uint32]$SampleRate
$profile.Audio.ChannelCount = [uint32]1
$tr = New-Object Windows.Media.Transcoding.MediaTranscoder
$prep = AwaitOp ($tr.PrepareFileTranscodeAsync($inFile, $outFile, $profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
if (-not $prep.CanTranscode) { Write-Error "CannotTranscode: $($prep.FailureReason)"; exit 2 }
AwaitActP ($prep.TranscodeAsync()) ([double])
Write-Output 'OK'
''';

  /// Transcodes [wavPath] to a compressed .m4a next to it and deletes the WAV.
  /// Returns the new path, or null if Windows couldn't transcode it (the WAV is kept).
  static Future<String?> compress(String wavPath) async {
    if (kIsWeb || !Platform.isWindows) return wavPath;

    final wav = File(wavPath);
    if (!wav.existsSync()) return null;

    final dir = wav.parent.path;
    final baseName = wav.uri.pathSegments.last.replaceAll(RegExp(r'\.wav$', caseSensitive: false), '');
    final outName = '$baseName.m4a';
    final outPath = '$dir${Platform.pathSeparator}$outName';
    final scriptFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}mihrab_compress_audio.ps1');

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
        wav.path,
        '-OutDir',
        dir,
        '-OutName',
        outName,
        '-Bitrate',
        '${MediaLimits.recordingBitRate}',
        '-SampleRate',
        '${MediaLimits.recordingSampleRate}',
      ]).timeout(const Duration(minutes: 10));

      final out = File(outPath);
      if (result.exitCode == 0 && out.existsSync() && out.lengthSync() > 0) {
        try {
          await wav.delete();
        } catch (_) {}
        return outPath;
      }
      debugPrint('⚠️ ضغط التسجيل فشل (${result.exitCode}): ${result.stderr}');
    } catch (e) {
      debugPrint('⚠️ ضغط التسجيل فشل: $e');
    }
    return null;
  }
}
