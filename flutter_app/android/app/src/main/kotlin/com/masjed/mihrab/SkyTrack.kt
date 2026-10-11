package com.masjed.mihrab

import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.floor

/**
 * سماء شريط المواقيت بين عيّنات يحسبها التطبيق (`SkyTrack` في Dart) بخوارزميات كرت
 * «الصلاة القادمة» نفسها. لا فلك هنا: استيفاء خطي بين عيّنتين كل عشرين دقيقة، فيُرسم
 * الشريط والتطبيق مغلق لأسبوعين.
 *
 * الارتفاعات بأعشار الدرجة، والإضاءة بالألف، والزاويتان بالدرجات.
 */
internal class SkyTrack(
    private val start: Long,
    private val step: Long,
    val eastOnRight: Boolean,
    private val sun: IntArray,
    private val moon: IntArray,
    private val lit: IntArray,
    private val limb: IntArray,
    private val par: IntArray
) {
    private val last get() = sun.size - 1

    fun covers(t: Long) = sun.size >= 2 && t >= start && t <= start + step * last

    fun sunAltitude(t: Long) = linear(sun, t) / 10.0

    /** ارتفاع القمر كما يُرى من سطح الأرض. */
    fun moonAltitude(t: Long) = linear(moon, t) / 10.0

    fun illumination(t: Long) = (linear(lit, t) / 1000.0).coerceIn(0.0, 1.0)

    /** زاوية الطرف المضيء من سمت الرأس (0 أعلى القرص، عكس عقارب الساعة). */
    fun limbZenithAngle(t: Long) = angular(limb, t)

    fun parallacticAngle(t: Long) = angular(par, t)

    fun moonUp(t: Long) = moonAltitude(t) >= MOON_HORIZON

    /** آخر طلوع للقمر قبل [t] (خلال [MOON_WINDOW_MS])، أو null. */
    fun moonRiseBefore(t: Long): Long? {
        var i = index(t).toInt().coerceIn(0, last - 1)
        val oldest = t - MOON_WINDOW_MS
        while (i >= 0 && timeAt(i + 1) >= oldest) {
            if (moon[i] < MOON_HORIZON_DECI && moon[i + 1] >= MOON_HORIZON_DECI) {
                val at = crossing(i)
                if (at <= t) return at
            }
            i--
        }
        return null
    }

    /** أول غروب للقمر بعد [t] (خلال [MOON_WINDOW_MS])، أو null. */
    fun moonSetAfter(t: Long): Long? {
        var i = index(t).toInt().coerceIn(0, last - 1)
        val latest = t + MOON_WINDOW_MS
        while (i < last && timeAt(i) <= latest) {
            if (moon[i] >= MOON_HORIZON_DECI && moon[i + 1] < MOON_HORIZON_DECI) {
                val at = crossing(i)
                if (at >= t) return at
            }
            i++
        }
        return null
    }

    private fun timeAt(i: Int) = start + step * i

    private fun index(t: Long) = (t - start).toDouble() / step

    /** لحظة عبور القمر عتبة الأفق بين العيّنتين [i] و[i]+1. */
    private fun crossing(i: Int): Long {
        val a = moon[i].toDouble()
        val b = moon[i + 1].toDouble()
        val f = if (a == b) 0.0 else (MOON_HORIZON_DECI - a) / (b - a)
        return timeAt(i) + (step * f.coerceIn(0.0, 1.0)).toLong()
    }

    private fun linear(values: IntArray, t: Long): Double {
        val x = index(t).coerceIn(0.0, last.toDouble())
        val i = floor(x).toInt().coerceAtMost(last - 1)
        return values[i] + (values[i + 1] - values[i]) * (x - i)
    }

    /** استيفاء زاوية على أقصر قوس: من 350° إلى 10° يمرّ بالصفر لا بـ180°. */
    private fun angular(values: IntArray, t: Long): Double {
        val x = index(t).coerceIn(0.0, last.toDouble())
        val i = floor(x).toInt().coerceAtMost(last - 1)
        var delta = (values[i + 1] - values[i]) % 360
        if (delta > 180) delta -= 360
        if (delta < -180) delta += 360
        return values[i] + delta * (x - i)
    }

    companion object {
        /** القمر يُعدّ طالعاً حين يبلغ طرفه العلوي الأفق مع الانكسار (كما في التطبيق). */
        const val MOON_HORIZON = -0.83
        private const val MOON_HORIZON_DECI = MOON_HORIZON * 10
        private const val MOON_WINDOW_MS = 26 * 3_600_000L

        /** يقرأ ما أرسله التطبيق، أو null إن غاب أو لم يكتمل. */
        fun parse(json: String?): SkyTrack? {
            if (json.isNullOrEmpty()) return null
            return try {
                val o = JSONObject(json)
                val sun = ints(o.getJSONArray("sun"))
                val columns = listOf("moon", "lit", "limb", "par").map { ints(o.getJSONArray(it)) }
                val step = o.getLong("step")
                if (sun.size < 2 || step <= 0 || columns.any { it.size != sun.size }) return null
                SkyTrack(
                    o.getLong("start"),
                    step,
                    o.optBoolean("east_right", false),
                    sun,
                    columns[0],
                    columns[1],
                    columns[2],
                    columns[3]
                )
            } catch (e: Exception) {
                null
            }
        }

        private fun ints(array: JSONArray) = IntArray(array.length()) { array.getInt(it) }
    }
}

/**
 * السماء عند لحظة: كل ما ترسمه [SkyScenePainter]. الشمس بين شروقها وغروبها من جدول
 * المواقيت نفسه المعروض في الشريط، والقمر بين طلوعه وغروبه من العيّنات.
 */
internal class SkyScene(
    val sunAltitude: Double,
    /** تجاوزت الشمس الزوال: شفقها جهة الغروب، وإلا فجهة الشروق. */
    val sunPastNoon: Boolean,
    /** موضع الشمس بين الشروق (0) والغروب (1). */
    val sunFraction: Double,
    /** ارتفاع الشمس على عيّنات متساوية من الشروق إلى الغروب. */
    val sunPath: DoubleArray,
    val moonUp: Boolean,
    val moonAltitude: Double,
    /** موضع القمر بين طلوعه (0) وغروبه (1). */
    val moonFraction: Double,
    val moonPath: DoubleArray,
    val illumination: Double,
    val limbZenithAngle: Double,
    val parallacticAngle: Double,
    val eastOnRight: Boolean
) {
    val sunUp get() = sunAltitude > SUN_HORIZON

    /** من 0 نهاراً إلى 1 ليلاً. */
    val night get() = ((-sunAltitude - 3) / 9).coerceIn(0.0, 1.0)

    companion object {
        private const val SUN_HORIZON = -0.8333
        private const val SAMPLES = 32
        private const val DAY_MS = 86_400_000L

        /** [sunrise] و[sunset] لليوم الذي فيه [now]، من جدول المواقيت. */
        fun at(track: SkyTrack, now: Long, sunrise: Long, sunset: Long): SkyScene? {
            if (!track.covers(now) || sunset <= sunrise) return null

            val dayLength = sunset - sunrise
            val sunFraction = ((now - sunrise).toDouble() / dayLength).coerceIn(0.0, 1.0)
            val sunPath = DoubleArray(SAMPLES + 1) { track.sunAltitude(sunrise + dayLength * it / SAMPLES) }
            // من الزوال إلى منتصف الليل الشمسي: الشمس في النصف الغربي
            val sinceNoon = Math.floorMod(now - (sunrise + sunset) / 2, DAY_MS)

            val moonUp = track.moonUp(now)
            var moonFraction = 0.5
            var moonPath = DoubleArray(0)
            if (moonUp) {
                val rise = track.moonRiseBefore(now)
                val set = track.moonSetAfter(now)
                if (rise != null && set != null && set > rise) {
                    val span = set - rise
                    moonFraction = ((now - rise).toDouble() / span).coerceIn(0.0, 1.0)
                    moonPath = DoubleArray(SAMPLES + 1) { track.moonAltitude(rise + span * it / SAMPLES) }
                }
            }

            return SkyScene(
                sunAltitude = track.sunAltitude(now),
                sunPastNoon = sinceNoon < DAY_MS / 2,
                sunFraction = sunFraction,
                sunPath = sunPath,
                moonUp = moonUp,
                moonAltitude = track.moonAltitude(now),
                moonFraction = moonFraction,
                moonPath = moonPath,
                illumination = track.illumination(now),
                limbZenithAngle = track.limbZenithAngle(now),
                parallacticAngle = track.parallacticAngle(now),
                eastOnRight = track.eastOnRight
            )
        }
    }
}
