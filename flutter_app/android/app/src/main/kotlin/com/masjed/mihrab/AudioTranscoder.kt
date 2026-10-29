package com.masjed.mihrab

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * يضغط تسجيلاً صوتياً جاهزاً (mp3، wav، m4a، ogg، amr...) إلى AAC (.m4a) أحادي بإعدادات
 * تسجيل الدرس نفسها (32kbps، 16kHz): الساعة نحو 14MB، تحت حد أرشيف تيليجرام.
 *
 * مفكّكات الترميز ومحرّك AAC من النظام نفسه، فلا مكتبة إضافية. جزء من الملف فقط يُضغط
 * عند [startMs] و[maxMs]، ليُقطَّع الدرس الطويل إلى أجزاء ساعة كما يفعل التسجيل المباشر.
 */
object AudioTranscoder {
    private const val TIMEOUT_US = 5_000L
    private const val SAMPLES_AHEAD = 16_000 * 4
    private const val MAX_IDLE_LOOPS = 4_000

    class Failure(message: String) : Exception(message)

    /** مدة الملف بالميلي ثانية، أو null إن لم يُقرأ كصوت. */
    fun durationMs(path: String): Long? {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val hasAudio = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)
            if (hasAudio != null && hasAudio != "yes") return null
            val millis = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
            if (millis != null && millis > 0) return millis
        } catch (_: Exception) {
            // يجرَّب المستخرج أدناه
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(path)
            val track = audioTrack(extractor) ?: return null
            val micros = extractor.getTrackFormat(track).let {
                if (it.containsKey(MediaFormat.KEY_DURATION)) it.getLong(MediaFormat.KEY_DURATION) else 0L
            }
            if (micros > 0) micros / 1000 else null
        } catch (_: Exception) {
            null
        } finally {
            extractor.release()
        }
    }

    private fun audioTrack(extractor: MediaExtractor): Int? {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("audio/")) return i
        }
        return null
    }

    /**
     * يضغط [inPath] إلى [outPath]. [startMs] بداية الجزء من الملف، و[maxMs] طوله (أو
     * سالب لحتى النهاية). يعيد مدة ما كُتب بالميلي ثانية؛ ويحذف [outPath] إن فشل.
     */
    fun transcode(inPath: String, outPath: String, bitRate: Int, sampleRate: Int, startMs: Long, maxMs: Long): Long {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var succeeded = false
        try {
            extractor.setDataSource(inPath)
            val track = audioTrack(extractor) ?: throw Failure("الملف لا يحوي مقطعاً صوتياً")
            extractor.selectTrack(track)
            val inFormat = extractor.getTrackFormat(track)
            val inMime = inFormat.getString(MediaFormat.KEY_MIME) ?: throw Failure("نوع الصوت غير معروف")

            val startUs = startMs.coerceAtLeast(0L) * 1000
            val limited = maxMs >= 0
            // الدفعات بعد نهاية الجزء بأكثر من ثانيتين لا حاجة لفكّها
            val stopFeedingUs = if (limited) startUs + maxMs * 1000 + 2_000_000L else Long.MAX_VALUE
            if (startUs > 0) extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            decoder = MediaCodec.createDecoderByType(inMime)
            decoder.configure(inFormat, null, null, 0)
            decoder.start()

            val outFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16 * 1024)
            }
            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            encoder.configure(outFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()

            File(outPath).delete()
            muxer = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var muxerTrack = -1

            // مواصفات الصوت المفكوك: تتأكد حين يعلنها المفكّك
            var decodedRate = if (inFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) inFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE) else sampleRate
            var decodedChannels = if (inFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) inFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 1
            var decodedEncoding = AudioFormat.ENCODING_PCM_16BIT

            val fifo = ShortFifo()
            var converter = PcmConverter(decodedRate, sampleRate, fifo)
            var reachedEnd = false

            val decoderInfo = MediaCodec.BufferInfo()
            val encoderInfo = MediaCodec.BufferInfo()
            var extractorDone = false
            var decoderDone = false
            var encoderEosQueued = false
            var encoderDone = false
            var encodedSamples = 0L
            val chunk = ShortArray(8 * 1024)
            var idle = 0

            while (!encoderDone) {
                var progressed = false

                // 1. من الملف إلى المفكّك
                if (!extractorDone) {
                    val index = decoder.dequeueInputBuffer(0)
                    if (index >= 0) {
                        val buffer = decoder.getInputBuffer(index)!!
                        val size = extractor.readSampleData(buffer, 0)
                        val time = extractor.sampleTime
                        if (size < 0 || time >= stopFeedingUs) {
                            decoder.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            extractorDone = true
                        } else {
                            decoder.queueInputBuffer(index, 0, size, time, 0)
                            extractor.advance()
                        }
                        progressed = true
                    }
                }

                // 2. من المفكّك إلى القائمة (أحادي، 16kHz)
                if (!decoderDone && fifo.size < SAMPLES_AHEAD) {
                    val index = decoder.dequeueOutputBuffer(decoderInfo, 0)
                    when {
                        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val format = decoder.outputFormat
                            decodedRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                            decodedChannels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                            decodedEncoding = if (format.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                                format.getInteger(MediaFormat.KEY_PCM_ENCODING)
                            } else {
                                AudioFormat.ENCODING_PCM_16BIT
                            }
                            converter = PcmConverter(decodedRate, sampleRate, fifo)
                            progressed = true
                        }
                        index >= 0 -> {
                            val buffer = decoder.getOutputBuffer(index)!!
                            if (decoderInfo.size > 0 && !reachedEnd) {
                                val ordered = buffer.order(ByteOrder.nativeOrder())
                                val bytesPerSample = PcmSamples.bytesPerSample(decodedEncoding)
                                val frameBytes = bytesPerSample * decodedChannels
                                val frames = decoderInfo.size / frameBytes
                                // إطارات هذه الدفعة التي تسبق بداية الجزء المطلوب
                                val bufferStartUs = decoderInfo.presentationTimeUs
                                // البحث يقف عند أقرب نقطة سابقة: ما قبل [startUs] يُهمَل
                                val skip = if (bufferStartUs < startUs) {
                                    (((startUs - bufferStartUs) * decodedRate) / 1_000_000L).toInt().coerceAtMost(frames)
                                } else {
                                    0
                                }
                                for (frame in skip until frames) {
                                    var sum = 0.0
                                    for (c in 0 until decodedChannels) {
                                        val at = decoderInfo.offset + frame * frameBytes + c * bytesPerSample
                                        sum += PcmSamples.read(ordered, at, decodedEncoding)
                                    }
                                    converter.push(sum / decodedChannels)
                                    // العدّ من المرمِّز والقائمة معاً: يبقى صحيحاً لو تبدّلت مواصفات الصوت في الأثناء
                                    if (limited && (encodedSamples + fifo.size) * 1000L >= maxMs * sampleRate) {
                                        reachedEnd = true
                                        break
                                    }
                                }
                            }
                            val last = (decoderInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                            decoder.releaseOutputBuffer(index, false)
                            if (last || reachedEnd) decoderDone = true
                            progressed = true
                        }
                    }
                }

                // 3. من القائمة إلى المرمِّز
                if (!encoderEosQueued) {
                    val ready = fifo.size > 0
                    if (ready || decoderDone) {
                        val index = encoder.dequeueInputBuffer(0)
                        if (index >= 0) {
                            val buffer = encoder.getInputBuffer(index)!!
                            buffer.clear()
                            val room = buffer.capacity() / 2
                            val count = fifo.read(chunk, minOf(room, chunk.size))
                            val pts = encodedSamples * 1_000_000L / sampleRate
                            if (count > 0) {
                                buffer.order(ByteOrder.nativeOrder()).asShortBuffer().put(chunk, 0, count)
                                buffer.position(0).limit(count * 2)
                                encoder.queueInputBuffer(index, 0, count * 2, pts, 0)
                                encodedSamples += count
                            } else {
                                encoder.queueInputBuffer(index, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                encoderEosQueued = true
                            }
                            progressed = true
                        }
                    }
                }

                // 4. من المرمِّز إلى الملف
                val outIndex = encoder.dequeueOutputBuffer(encoderInfo, if (progressed) 0 else TIMEOUT_US)
                when {
                    outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        muxerTrack = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        muxerStarted = true
                        progressed = true
                    }
                    outIndex >= 0 -> {
                        val buffer = encoder.getOutputBuffer(outIndex)!!
                        val isConfig = (encoderInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                        if (encoderInfo.size > 0 && !isConfig && muxerStarted) {
                            buffer.position(encoderInfo.offset)
                            buffer.limit(encoderInfo.offset + encoderInfo.size)
                            muxer.writeSampleData(muxerTrack, buffer, encoderInfo)
                        }
                        encoder.releaseOutputBuffer(outIndex, false)
                        if ((encoderInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) encoderDone = true
                        progressed = true
                    }
                }

                idle = if (progressed) 0 else idle + 1
                if (idle > MAX_IDLE_LOOPS) throw Failure("توقف ضغط الصوت دون تقدم")
            }

            if (encodedSamples <= 0) throw Failure("لم يُقرأ أي صوت من الملف")
            if (muxerStarted) {
                muxerStarted = false
                muxer.stop()
            }
            succeeded = true
            return encodedSamples * 1000L / sampleRate
        } catch (e: Failure) {
            throw e
        } catch (e: Exception) {
            throw Failure(e.message ?: e.javaClass.simpleName)
        } finally {
            try {
                decoder?.stop()
            } catch (_: Exception) {
            }
            try {
                decoder?.release()
            } catch (_: Exception) {
            }
            try {
                encoder?.stop()
            } catch (_: Exception) {
            }
            try {
                encoder?.release()
            } catch (_: Exception) {
            }
            try {
                if (muxerStarted) muxer?.stop()
            } catch (_: Exception) {
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
            extractor.release()
            if (!succeeded) File(outPath).delete()
        }
    }
}
