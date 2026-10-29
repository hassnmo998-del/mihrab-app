package com.masjed.mihrab

import android.media.AudioFormat
import java.nio.ByteBuffer

/**
 * عيّنات الصوت المفكوك كما يسلّمها المفكّك: 16 بت في الغالب، لكن ملف WAV من مسجّل
 * احترافي قد يكون 24 بت أو عائماً، ومن مسجّل قديم 8 بت.
 */
object PcmSamples {
    fun bytesPerSample(encoding: Int): Int = when (encoding) {
        AudioFormat.ENCODING_PCM_8BIT -> 1
        AudioFormat.ENCODING_PCM_24BIT_PACKED -> 3
        AudioFormat.ENCODING_PCM_32BIT, AudioFormat.ENCODING_PCM_FLOAT -> 4
        else -> 2
    }

    /** العيّنة عند [byteIndex] (فهرس مطلق في [buffer]) بين -1 و 1. */
    fun read(buffer: ByteBuffer, byteIndex: Int, encoding: Int): Double = when (encoding) {
        AudioFormat.ENCODING_PCM_8BIT -> ((buffer.get(byteIndex).toInt() and 0xFF) - 128) / 128.0
        AudioFormat.ENCODING_PCM_24BIT_PACKED -> {
            // ثلاثة بايتات، أقلها وزناً أولاً؛ الإشارة من الأخير
            val b0 = buffer.get(byteIndex).toInt() and 0xFF
            val b1 = buffer.get(byteIndex + 1).toInt() and 0xFF
            val b2 = buffer.get(byteIndex + 2).toInt()
            ((b2 shl 16) or (b1 shl 8) or b0) / 8388608.0
        }
        AudioFormat.ENCODING_PCM_32BIT -> buffer.getInt(byteIndex) / 2147483648.0
        AudioFormat.ENCODING_PCM_FLOAT -> buffer.getFloat(byteIndex).toDouble()
        else -> buffer.getShort(byteIndex) / 32768.0
    }
}

/**
 * قائمة عيّنات 16 بت تُكتب من جهة وتُقرأ من الأخرى: ما بين فكّ الترميز والترميز.
 */
class ShortFifo(initialCapacity: Int = 1 shl 15) {
    private var data = ShortArray(initialCapacity)
    private var head = 0
    private var tail = 0

    val size: Int get() = tail - head

    fun write(value: Short) {
        if (tail == data.size) {
            if (head > 0) {
                // أفرغ ما قُرئ بدل أن تكبر القائمة بلا حد
                System.arraycopy(data, head, data, 0, size)
                tail -= head
                head = 0
            } else {
                data = data.copyOf(data.size * 2)
            }
        }
        data[tail++] = value
    }

    /** يقرأ حتى [max] عيّنة إلى [dest] ويعيد عددها. */
    fun read(dest: ShortArray, max: Int): Int {
        val n = minOf(max, size, dest.size)
        System.arraycopy(data, head, dest, 0, n)
        head += n
        if (head == tail) {
            head = 0
            tail = 0
        }
        return n
    }
}

/**
 * يحوّل صوتاً مفكوك الترميز إلى أحادي بتردد التسجيل (16kHz): المتوسط بين القنوات ثم
 * إعادة أخذ عيّنات متدفقة، فلا حاجة لحمل الملف كله في الذاكرة.
 *
 * التقليل من التردد (44.1kHz → 16kHz) بمتوسط مساحة النافذة كي لا تنعكس الترددات
 * العالية على الكلام؛ والرفع منه (8kHz → 16kHz) بالاستيفاء الخطي.
 */
class PcmConverter(private val inRate: Int, private val outRate: Int, private val out: ShortFifo) {
    private val step = inRate.toDouble() / outRate

    // الفهرس المطلق للعيّنة التالية في الدخل، وللعيّنة التالية في الخرج
    private var inIndex = 0L
    private var outIndex = 0L

    // نافذة المتوسط (تقليل التردد)
    private var accumulator = 0.0

    // الاستيفاء (رفع التردد)
    private var previous = 0.0

    /** عدد عيّنات الخرج المكتوبة حتى الآن. */
    val written: Long get() = outIndex

    /**
     * عيّنة أحادية واحدة بين -1 و 1. تُسلَّم متتابعة؛ يُكتب الخرج في القائمة
     * كلما اكتملت عيّنة منه.
     */
    fun push(sample: Double) {
        if (inRate == outRate) {
            emit(sample)
            inIndex++
            return
        }
        if (step > 1.0) {
            var segStart = inIndex.toDouble()
            val segEnd = inIndex + 1.0
            while (segStart < segEnd) {
                val windowEnd = (outIndex + 1) * step
                val stop = minOf(segEnd, windowEnd)
                accumulator += sample * (stop - segStart)
                segStart = stop
                if (stop >= windowEnd - 1e-9) {
                    val value = accumulator / step
                    accumulator = 0.0
                    emit(value)
                }
            }
        } else {
            if (inIndex > 0) {
                var position = outIndex * step
                while (position < inIndex) {
                    val frac = position - (inIndex - 1)
                    emit(previous + (sample - previous) * frac)
                    position = outIndex * step
                }
            }
            previous = sample
        }
        inIndex++
    }

    private fun emit(value: Double) {
        val scaled = (value * 32767.0).toInt().coerceIn(-32768, 32767)
        out.write(scaled.toShort())
        outIndex++
    }
}
