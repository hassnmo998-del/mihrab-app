package com.masjed.mihrab

import android.media.AudioFormat
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * تحويل الصوت المفكوك إلى أحادي 16kHz قبل ضغطه: عدد العيّنات، السعة، وعدم انعكاس
 * الترددات العالية على الكلام. (المفكّك والمرمِّز من النظام ولا يعملان خارج الجهاز.)
 */
class PcmConverterTest {
    private fun convert(inRate: Int, outRate: Int, seconds: Double, signal: (Double) -> Double): ShortArray {
        val fifo = ShortFifo()
        val converter = PcmConverter(inRate, outRate, fifo)
        val total = (inRate * seconds).toInt()
        for (n in 0 until total) converter.push(signal(n.toDouble() / inRate))
        val out = ShortArray(fifo.size)
        fifo.read(out, out.size)
        return out
    }

    private fun rms(samples: ShortArray, from: Int = 0): Double {
        var sum = 0.0
        for (i in from until samples.size) sum += samples[i].toDouble() * samples[i]
        return sqrt(sum / (samples.size - from))
    }

    @Test
    fun sameRateIsPassedThrough() {
        val out = convert(16000, 16000, 1.0) { 0.25 }
        assertEquals(16000, out.size)
        assertTrue(out.all { abs(it - 8191) <= 1 })
    }

    @Test
    fun downsamplingKeepsTheCountAndTheLevel() {
        for (inRate in listOf(48000, 44100, 22050)) {
            val out = convert(inRate, 16000, 2.0) { 0.5 }
            assertTrue("$inRate: ${out.size}", abs(out.size - 32000) <= 1)
            assertTrue("$inRate: DC kept", out.all { abs(it - 16383) <= 2 })
        }
    }

    @Test
    fun aSpeechBandToneKeepsItsAmplitude() {
        val out = convert(44100, 16000, 1.0) { 0.5 * sin(2 * PI * 440 * it) }
        // سعة 0.5 جيبية: القيمة الفعالة 0.3535 * 32767
        val expected = 0.5 / sqrt(2.0) * 32767
        assertTrue("rms ${rms(out)}", abs(rms(out) - expected) < expected * 0.03)
    }

    @Test
    fun aToneAboveTheNewNyquistIsAttenuatedNotFolded() {
        // 12kHz في ملف 44.1kHz لا يُمثَّل بـ16kHz: يجب أن يخف لا أن ينعكس كصوت مسموع
        val out = convert(44100, 16000, 1.0) { 0.5 * sin(2 * PI * 12000 * it) }
        val original = 0.5 / sqrt(2.0) * 32767
        assertTrue("rms ${rms(out)}", rms(out) < original * 0.5)
    }

    @Test
    fun upsamplingInterpolatesBetweenSamples() {
        val out = convert(8000, 16000, 1.0) { 0.5 }
        assertTrue("count ${out.size}", abs(out.size - 16000) <= 2)
        assertTrue(out.all { abs(it - 16383) <= 2 })

        // سلّم صاعد: الخرج يمرّ بالقيم الوسيطة
        val fifo = ShortFifo()
        val converter = PcmConverter(8000, 16000, fifo)
        for (n in 0 until 10) converter.push(n / 10.0)
        val ramp = ShortArray(fifo.size)
        fifo.read(ramp, ramp.size)
        assertTrue(ramp.size >= 17)
        for (i in 1 until ramp.size) assertTrue("monotonic at $i", ramp[i] >= ramp[i - 1])
        assertEquals(0, ramp[0].toInt())
        assertTrue(abs(ramp[1] - 1638) <= 2) // نصف الخطوة الأولى (0.05)
    }

    @Test
    fun theOutputCountIsStableAcrossHowTheInputIsSliced() {
        // المفكّك يسلّم دفعات بأحجام مختلفة؛ العدّ لا يتأثر بها
        val fifo = ShortFifo()
        val converter = PcmConverter(44100, 16000, fifo)
        val total = 44100 * 3
        for (n in 0 until total) converter.push(0.1)
        assertEquals(converter.written.toInt(), fifo.size)
        assertTrue(abs(fifo.size - 48000) <= 1)
    }

    @Test
    fun fifoKeepsOrderAcrossReadsAndGrowth() {
        val fifo = ShortFifo(4)
        var next = 0
        val seen = ArrayList<Short>()
        val buffer = ShortArray(3)
        for (round in 0 until 50) {
            for (i in 0 until 7) fifo.write((next++).toShort())
            val n = fifo.read(buffer, 3)
            for (i in 0 until n) seen.add(buffer[i])
        }
        while (fifo.size > 0) {
            val n = fifo.read(buffer, 3)
            for (i in 0 until n) seen.add(buffer[i])
        }
        assertEquals(350, seen.size)
        for (i in seen.indices) assertEquals(i.toShort(), seen[i])
    }

    private fun bytes(vararg values: Int): ByteBuffer =
        ByteBuffer.allocate(values.size).order(ByteOrder.LITTLE_ENDIAN).also { buffer ->
            values.forEach { buffer.put(it.toByte()) }
        }

    @Test
    fun samplesAreReadFromEveryPcmEncodingTheDecoderMayDeliver() {
        // 16 بت: -16384 = نصف السالب
        val pcm16 = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putShort(16384).putShort(-16384)
        assertEquals(0.5, PcmSamples.read(pcm16, 0, AudioFormat.ENCODING_PCM_16BIT), 1e-9)
        assertEquals(-0.5, PcmSamples.read(pcm16, 2, AudioFormat.ENCODING_PCM_16BIT), 1e-9)

        // 8 بت بلا إشارة: 128 صمت
        val pcm8 = bytes(128, 255, 0)
        assertEquals(0.0, PcmSamples.read(pcm8, 0, AudioFormat.ENCODING_PCM_8BIT), 1e-9)
        assertTrue(PcmSamples.read(pcm8, 1, AudioFormat.ENCODING_PCM_8BIT) > 0.99)
        assertEquals(-1.0, PcmSamples.read(pcm8, 2, AudioFormat.ENCODING_PCM_8BIT), 1e-9)

        // 24 بت (مسجّلات احترافية): +0.5 ثم -0.5
        val pcm24 = bytes(0x00, 0x00, 0x40, 0x00, 0x00, 0xC0)
        assertEquals(0.5, PcmSamples.read(pcm24, 0, AudioFormat.ENCODING_PCM_24BIT_PACKED), 1e-9)
        assertEquals(-0.5, PcmSamples.read(pcm24, 3, AudioFormat.ENCODING_PCM_24BIT_PACKED), 1e-9)

        val pcm32 = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(Int.MIN_VALUE / 2)
        assertEquals(-0.5, PcmSamples.read(pcm32, 0, AudioFormat.ENCODING_PCM_32BIT), 1e-9)

        val float = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putFloat(0.25f)
        assertEquals(0.25, PcmSamples.read(float, 0, AudioFormat.ENCODING_PCM_FLOAT), 1e-9)
    }

    @Test
    fun bytesPerSampleMatchesTheEncoding() {
        assertEquals(1, PcmSamples.bytesPerSample(AudioFormat.ENCODING_PCM_8BIT))
        assertEquals(2, PcmSamples.bytesPerSample(AudioFormat.ENCODING_PCM_16BIT))
        assertEquals(3, PcmSamples.bytesPerSample(AudioFormat.ENCODING_PCM_24BIT_PACKED))
        assertEquals(4, PcmSamples.bytesPerSample(AudioFormat.ENCODING_PCM_32BIT))
        assertEquals(4, PcmSamples.bytesPerSample(AudioFormat.ENCODING_PCM_FLOAT))
    }
}
