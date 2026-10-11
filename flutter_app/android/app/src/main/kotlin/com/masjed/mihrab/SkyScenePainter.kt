package com.masjed.mihrab

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import java.util.Random
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * يرسم سماء اللحظة لشريط المواقيت في الإشعارات: هي لوحة `SkyPainter` في التطبيق نفسها
 * (sky_day_strip.dart) منقولة إلى لوحة أندرويد، بالألوان والنِّسب نفسها. أي تعديل في إحداهما
 * يُنقل إلى الأخرى.
 *
 * اللوحة منظر حقيقي لا مخطط زمني: الشرق حيث يراه الراصد ([SkyScene.eastOnRight])، ولا
 * تنقلب مع اتجاه النص.
 */
internal object SkyScenePainter {

    /** (ارتفاع الشمس، لون أعلى السماء، لون الأفق) */
    private val SKY_KEYS = arrayOf(
        Triple(-18.0, 0xFF050A1C.toInt(), 0xFF0D1633.toInt()),
        Triple(-12.0, 0xFF0A1230.toInt(), 0xFF1C2A57.toInt()),
        Triple(-6.0, 0xFF1A2456.toInt(), 0xFF7C4A76.toInt()),
        Triple(-2.0, 0xFF2B3A78.toInt(), 0xFFE38A63.toInt()),
        Triple(0.0, 0xFF3C5A9E.toInt(), 0xFFF6AE6A.toInt()),
        Triple(6.0, 0xFF3E86D8.toInt(), 0xFFD5E2EC.toInt()),
        Triple(15.0, 0xFF2F80E4.toInt(), 0xFFA6D2F7.toInt()),
        Triple(90.0, 0xFF1F6FDB.toInt(), 0xFF8FC6F5.toInt())
    )

    /** بحار القمر: (س، ص، نصف القطر) بنسبة نصف قطر القرص. */
    private val MARIA = arrayOf(
        floatArrayOf(-0.30f, -0.42f, 0.30f),
        floatArrayOf(0.22f, -0.32f, 0.20f),
        floatArrayOf(0.38f, -0.05f, 0.22f),
        floatArrayOf(0.68f, -0.22f, 0.11f),
        floatArrayOf(-0.58f, -0.05f, 0.28f),
        floatArrayOf(-0.25f, 0.42f, 0.22f),
        floatArrayOf(0.52f, 0.22f, 0.14f)
    )

    /**
     * لوحة السماء أعلى الإشعار الموسّع.
     *
     * @param dp بكسلات الصورة لكل وحدة تصميم
     * @param ground ارتفاع شريط الأرض أسفل اللوحة (عليه موعد الشروق أو الغروب القادم)
     * @param topRadius استدارة الزاويتين العلويتين، لتطابق بطاقة الإشعار
     */
    fun strip(scene: SkyScene, width: Int, height: Int, dp: Float, ground: Float, topRadius: Float): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val w = width.toFloat()
        val h = height.toFloat()
        val horizonY = h - ground
        val r = discRadius(h, dp)
        val night = scene.night.toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        canvas.clipPath(Path().apply {
            addRoundRect(
                RectF(0f, 0f, w, h),
                floatArrayOf(topRadius, topRadius, topRadius, topRadius, 0f, 0f, 0f, 0f),
                Path.Direction.CW
            )
        })

        // 1) السماء
        val (top, horizon) = skyColors(scene.sunAltitude)
        paint.shader = LinearGradient(0f, 0f, 0f, horizonY, top, horizon, Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, w, h, paint)
        paint.shader = null

        // 2) النجوم
        if (night > 0f) {
            val random = Random(11)
            for (i in 0 until 46) {
                val x = random.nextFloat() * w
                val y = random.nextFloat() * (horizonY - 8 * dp)
                val size = (0.45f + random.nextFloat() * 0.85f) * dp
                val fade = 1 - 0.65f * (y / horizonY)
                paint.color = withAlpha(Color.WHITE, night * fade * (0.35f + random.nextFloat() * 0.65f))
                canvas.drawCircle(x, y, size, paint)
            }
        }

        canvas.save()
        canvas.clipRect(0f, 0f, w, horizonY)

        // 3) وهج الأفق عند الشروق والغروب، جهة الشمس
        val glow = (1 - abs(scene.sunAltitude + 2) / 12).coerceIn(0.0, 1.0).toFloat()
        if (glow > 0f) {
            val side = if (scene.sunUp) scene.sunFraction else if (scene.sunPastNoon) 1.0 else 0.0
            val cx = bodyX(w, r, dp, side, scene.eastOnRight)
            val radius = w * 0.5f
            paint.shader = RadialGradient(
                cx, horizonY, radius,
                intArrayOf(
                    withAlpha(0xFFC27A, 0.80f * glow),
                    withAlpha(0xFF8560, 0.32f * glow),
                    withAlpha(0xFF8560, 0f)
                ),
                floatArrayOf(0f, 0.42f, 1f),
                Shader.TileMode.CLAMP
            )
            canvas.drawCircle(cx, horizonY, radius, paint)
            paint.shader = null
        }

        // 4) القوسان: مسار الشمس نهاراً ومسار القمر ليلاً
        if (scene.sunUp) {
            dots(canvas, paint, w, horizonY, r, dp, scene.sunPath, withAlpha(Color.WHITE, 0.42f), scene.eastOnRight)
        } else if (scene.moonUp) {
            dots(canvas, paint, w, horizonY, r, dp, scene.moonPath, withAlpha(0xDDE6FF, 0.30f), scene.eastOnRight)
        }

        // 5) القمر ثم الشمس
        if (scene.moonUp) {
            val cx = bodyX(w, r, dp, scene.moonFraction, scene.eastOnRight)
            val cy = bodyY(horizonY, r, dp, scene.moonAltitude)
            val moonRadius = r * 0.95f
            if (night > 0.05f) {
                val halo = moonRadius * 2.9f
                paint.shader = RadialGradient(
                    cx, cy, halo,
                    withAlpha(Color.WHITE, 0.30f * night * scene.illumination.toFloat()),
                    withAlpha(Color.WHITE, 0f),
                    Shader.TileMode.CLAMP
                )
                canvas.drawCircle(cx, cy, halo, paint)
                paint.shader = null
            }
            moonDisc(canvas, cx, cy, moonRadius, scene, night)
        }
        if (scene.sunUp) {
            sunDisc(
                canvas, paint,
                bodyX(w, r, dp, scene.sunFraction, scene.eastOnRight),
                bodyY(horizonY, r, dp, scene.sunAltitude),
                r, r * 3.6f, scene.sunAltitude
            )
        }
        canvas.restore()

        // 6) الأرض: تلال هادئة وشريط داكن
        paint.color = Color.argb(((0.34f + 0.46f * night) * 255).roundToInt(), 7, 12, 26)
        val hills = Path().apply {
            moveTo(0f, horizonY - 2 * dp)
            quadTo(w * 0.12f, horizonY - 6 * dp, w * 0.27f, horizonY - 2.5f * dp)
            quadTo(w * 0.40f, horizonY, w * 0.52f, horizonY - 3.5f * dp)
            quadTo(w * 0.66f, horizonY - 7 * dp, w * 0.80f, horizonY - 2.5f * dp)
            quadTo(w * 0.92f, horizonY, w, horizonY - 3 * dp)
            lineTo(w, h)
            lineTo(0f, h)
            close()
        }
        canvas.drawPath(hills, paint)
        canvas.drawRect(0f, horizonY, w, h, paint)
        return bitmap
    }

    /**
     * الجرم الظاهر الآن في مربع صغير بجانب اسم الصلاة: الشمس نهاراً، وإلا القمر بطوره
     * وميلانه إن كان فوق الأفق، وإلا لا شيء.
     */
    fun glyph(scene: SkyScene, size: Int): Bitmap? {
        if (!scene.sunUp && !scene.moonUp) return null
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val c = size / 2f
        if (scene.sunUp) {
            sunDisc(canvas, Paint(Paint.ANTI_ALIAS_FLAG), c, c, size * 0.30f, c, scene.sunAltitude)
        } else {
            moonDisc(canvas, c, c, c - size * 0.04f, scene, 1f)
        }
        return bitmap
    }

    /** لونا السماء (الأعلى ثم الأفق) عند ارتفاع الشمس المعطى. */
    fun skyColors(sunAltitude: Double): Pair<Int, Int> {
        val first = SKY_KEYS.first()
        if (sunAltitude <= first.first) return first.second to first.third
        for (i in 1 until SKY_KEYS.size) {
            val a = SKY_KEYS[i - 1]
            val b = SKY_KEYS[i]
            if (sunAltitude <= b.first) {
                val t = ((sunAltitude - a.first) / (b.first - a.first)).toFloat()
                return lerp(a.second, b.second, t) to lerp(a.third, b.third, t)
            }
        }
        val last = SKY_KEYS.last()
        return last.second to last.third
    }

    /** نصف قطر القرصين من ارتفاع اللوحة. */
    private fun discRadius(height: Float, dp: Float) = (height * 0.115f).coerceIn(9 * dp, 15 * dp)

    /** أفقياً بنسبة ما قطع الجرم من مساره، من الشرق إلى الغرب. */
    private fun bodyX(w: Float, r: Float, dp: Float, fraction: Double, eastOnRight: Boolean): Float {
        val pad = r + 12 * dp
        val x = pad + fraction.coerceIn(0.0, 1.0).toFloat() * (w - 2 * pad)
        return if (eastOnRight) w - x else x
    }

    /** رأسياً بجيب الارتفاع (إسقاط القبة السماوية): شمس الشتاء أوطأ من شمس الصيف. */
    private fun bodyY(horizonY: Float, r: Float, dp: Float, altitude: Double): Float {
        val skyHeight = horizonY - (r + 7 * dp)
        return horizonY - sin(Math.toRadians(altitude.coerceIn(-10.0, 90.0))).toFloat() * skyHeight
    }

    /** قوس منقّط بتباعد ثابت مهما كان عرض اللوحة (الارتفاع بين العيّنات بالاستيفاء). */
    private fun dots(
        canvas: Canvas,
        paint: Paint,
        w: Float,
        horizonY: Float,
        r: Float,
        dp: Float,
        path: DoubleArray,
        color: Int,
        eastOnRight: Boolean
    ) {
        if (path.size < 2) return
        paint.color = color
        val count = (w / (9 * dp)).roundToInt().coerceIn(16, 160)
        val last = path.size - 1
        for (i in 0..count) {
            val f = i.toDouble() / count
            val at = f * last
            val lo = at.toInt().coerceIn(0, last - 1)
            val altitude = path[lo] + (path[lo + 1] - path[lo]) * (at - lo)
            if (altitude < 0) continue
            canvas.drawCircle(bodyX(w, r, dp, f, eastOnRight), bodyY(horizonY, r, dp, altitude), 1.1f * dp, paint)
        }
    }

    /** قرب الأفق يحمرّ القرص، وفي كبد السماء يبيضّ. */
    private fun sunDisc(canvas: Canvas, paint: Paint, cx: Float, cy: Float, r: Float, halo: Float, altitude: Double) {
        val warm = ((14 - altitude) / 14).coerceIn(0.0, 1.0).toFloat()
        val core = lerp(0xFFFFFDF0.toInt(), 0xFFFFE3A8.toInt(), warm)
        val rim = lerp(0xFFFFE27A.toInt(), 0xFFFF8A3D.toInt(), warm)
        paint.shader = RadialGradient(
            cx, cy, halo,
            intArrayOf(withAlpha(rim, 0.55f), withAlpha(rim, 0.16f), withAlpha(rim, 0f)),
            floatArrayOf(0f, 0.45f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, halo, paint)
        paint.shader = RadialGradient(cx, cy, r, intArrayOf(core, rim), floatArrayOf(0.55f, 1f), Shader.TileMode.CLAMP)
        canvas.drawCircle(cx, cy, r, paint)
        paint.shader = null
    }

    /**
     * قرص القمر بطوره وميلانه: المضيء نصف دائرة جهة الشمس وحدّ الإضاءة قطع ناقص عرضه من
     * نسبة الإضاءة، والكل مدوَّر بزاوية الطرف المضيء كما تُرى من مكان الراصد.
     */
    private fun moonDisc(canvas: Canvas, cx: Float, cy: Float, radius: Float, scene: SkyScene, night: Float) {
        val k = scene.illumination.toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.save()
        canvas.translate(cx, cy)

        // الجزء المعتم: يُرى ليلاً بنور الأرض، ويذوب في زرقة السماء نهاراً
        paint.color = withAlpha(0x18203A, 0.03f + 0.87f * night)
        canvas.drawCircle(0f, 0f, radius, paint)

        // 0 أعلى القرص، وتزيد عكس عقارب الساعة كما يراها الراصد؛ ومحور الشاشة الرأسي إلى الأسفل
        val z = Math.toRadians(scene.limbZenithAngle)
        val limbRotation = Math.toDegrees(atan2(-cos(z), -sin(z))).toFloat()

        val steps = 40
        val lit = Path()
        for (i in 0..steps) {
            val t = -Math.PI / 2 + Math.PI * i / steps
            val x = radius * cos(t).toFloat()
            val y = radius * sin(t).toFloat()
            if (i == 0) lit.moveTo(x, y) else lit.lineTo(x, y)
        }
        val terminator = radius * (1 - 2 * k)
        for (i in 0..steps) {
            val t = Math.PI / 2 - Math.PI * i / steps
            lit.lineTo(terminator * cos(t).toFloat(), radius * sin(t).toFloat())
        }
        lit.close()

        canvas.save()
        canvas.rotate(limbRotation)
        paint.shader = RadialGradient(
            0.35f * radius, 0f, 2 * radius,
            withAlpha(0xFFFEF6, 0.82f + 0.18f * night),
            withAlpha(0xE4DFCB, 0.78f + 0.22f * night),
            Shader.TileMode.CLAMP
        )
        canvas.drawPath(lit, paint)
        paint.shader = null

        // بحار القمر: بقع باهتة تثبت على وجهه، تميل معه بالزاوية البارالاكتية
        canvas.clipPath(lit)
        canvas.rotate(-limbRotation + scene.parallacticAngle.toFloat())
        paint.color = withAlpha(0x7F7C6E, 0.20f + 0.06f * night)
        paint.maskFilter = BlurMaskFilter(max(0.5f, radius * 0.07f), BlurMaskFilter.Blur.NORMAL)
        for (m in MARIA) {
            canvas.drawCircle(m[0] * radius, m[1] * radius, m[2] * radius, paint)
        }
        canvas.restore()

        canvas.restore()
    }

    private fun withAlpha(rgb: Int, alpha: Float): Int =
        (min(255, max(0, (alpha * 255).roundToInt())) shl 24) or (rgb and 0xFFFFFF)

    private fun lerp(a: Int, b: Int, t: Float): Int {
        val f = t.coerceIn(0f, 1f)
        fun channel(shift: Int): Int {
            val x = (a ushr shift) and 0xFF
            val y = (b ushr shift) and 0xFF
            return (x + (y - x) * f).roundToInt()
        }
        return (channel(24) shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
    }
}
