package com.masjed.mihrab

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.RemoteViews
import android.widget.TextView
import org.json.JSONArray
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.io.FileOutputStream
import java.util.Calendar
import java.util.TimeZone
import kotlin.math.abs

/**
 * شريط المواقيت في الإشعارات كما يرسمه أندرويد، من بيانات حقيقية أرسلها التطبيق (دمشق،
 * من 10 تشرين الأول 2026): السماء المستوفاة تطابق الحساب المباشر، والإشعار يحمل لوحة
 * السماء بحال اللحظة وموعداً واحداً (الغروب أو الشروق القادم).
 *
 * يكتب صور الإشعار في `flutter_app/build/notification-shots` لتُراجَع بالعين.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w360dp-h800dp-xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class PrayerNotificationSkyTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val timeline = resource("prayer_timeline.json")
    private val sky = resource("sky_track.json")
    private val track = SkyTrack.parse(sky)!!

    private fun resource(name: String) = javaClass.classLoader!!.getResource(name)!!.readText()

    // البيانات لدمشق: الأيام والساعات تُقرأ بتوقيتها أينما شُغّل الاختبار
    private val machineZone = TimeZone.getDefault()

    @Before
    fun useDamascusTime() = TimeZone.setDefault(TimeZone.getTimeZone("Asia/Damascus"))

    @After
    fun restoreTime() = TimeZone.setDefault(machineZone)

    private fun at(day: Int, hour: Int, minute: Int): Long = Calendar.getInstance().apply {
        clear()
        set(2026, Calendar.OCTOBER, day, hour, minute)
    }.timeInMillis

    // ─── السماء المستوفاة ────────────────────────────────────────────────

    @Test
    fun interpolatedSkyMatchesTheAppsOwnComputation() {
        val checks = JSONArray(resource("sky_checks.json"))
        assertTrue(checks.length() > 30)
        for (i in 0 until checks.length()) {
            val c = checks.getJSONObject(i)
            val t = c.getLong("t")
            assertEquals("sun @$t", c.getDouble("sun"), track.sunAltitude(t), 0.2)
            assertEquals("moon @$t", c.getDouble("moon"), track.moonAltitude(t), 0.5)
            assertEquals("lit @$t", c.getDouble("lit"), track.illumination(t), 0.003)

            // قرب الأفق تماماً قد يختلف «طالع» بين العتبتين؛ خارجه يجب أن يتفقا
            if (abs(c.getDouble("moon") - SkyTrack.MOON_HORIZON) > 0.6) {
                assertEquals("moon up @$t", c.getBoolean("up"), track.moonUp(t))
            }
            if (c.getBoolean("up") && !c.isNull("rise") && !c.isNull("set") && track.moonUp(t)) {
                val minutes = 60_000.0
                assertEquals("moonrise @$t", c.getLong("rise") / minutes, track.moonRiseBefore(t)!! / minutes, 4.0)
                assertEquals("moonset @$t", c.getLong("set") / minutes, track.moonSetAfter(t)!! / minutes, 4.0)
            }
            // الطرف المضيء: حين يُرى هلال، لا ينحرف ميلانه عن الحساب
            if (c.getDouble("lit") > 0.04) {
                val d = abs(c.getDouble("limb") - track.limbZenithAngle(t)) % 360
                assertTrue("limb @$t", minOf(d, 360 - d) < 4.0)
            }
        }
    }

    @Test
    fun angleInterpolationTakesTheShortArc() {
        // من 350° إلى 10° في خطوة واحدة: المنتصف 0° لا 180°
        val wrap = SkyTrack(0, 1000, false, intArrayOf(0, 0), intArrayOf(0, 0), intArrayOf(0, 0), intArrayOf(350, 10), intArrayOf(-170, 170))
        assertEquals(360.0, wrap.limbZenithAngle(500), 0.01)
        assertEquals(-180.0, wrap.parallacticAngle(500), 0.01)
    }

    @Test
    fun trackOutsideItsRangeOrBrokenGivesNoScene() {
        assertNull(SkyTrack.parse(null))
        assertNull(SkyTrack.parse("{}"))
        assertNull(SkyTrack.parse("""{"start":0,"step":1000,"sun":[1,2],"moon":[1],"lit":[1,2],"limb":[1,2],"par":[1,2]}"""))
        // بعد آخر عيّنة (لم يُفتح التطبيق منذ أسبوعين): لا لوحة، والشريط يبقى بمواقيته
        assertNull(SkyScene.at(track, at(30, 12, 0), at(30, 6, 40), at(30, 17, 50)))
    }

    // ─── الإشعار نفسه ────────────────────────────────────────────────────

    private class Shot(val small: View, val big: View)

    /** يرسم القالبين كما يرسمهما النظام، ويحفظهما صورة باسم [name]. */
    private fun render(name: String, now: Long, withSky: Boolean = true): Shot {
        val views = PrayerNotificationManager.viewsAt(context, timeline, if (withSky) sky else null, now)
        assertNotNull(name, views)
        val small = inflate(views!!.first)
        val big = inflate(views.second)
        save(name, small, big)
        return Shot(small, big)
    }

    private fun inflate(remote: RemoteViews): View {
        val density = context.resources.displayMetrics.density
        // عرض محتوى الإشعار في لوحة الإشعارات على هاتف 360dp
        val width = (296 * density).toInt()
        val view = remote.apply(context, FrameLayout(context))
        view.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        return view
    }

    private fun save(name: String, small: View, big: View) {
        val gap = 24
        val bitmap = Bitmap.createBitmap(small.width + 2 * gap, small.height + big.height + 3 * gap, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(0xFFECEFF1.toInt())
        canvas.translate(gap.toFloat(), gap.toFloat())
        small.draw(canvas)
        canvas.translate(0f, (small.height + gap).toFloat())
        big.draw(canvas)
        // مجلد بناء Flutter (خارج git)، لا android/app
        val dir = File("../../build/notification-shots").apply { mkdirs() }
        FileOutputStream(File(dir, "$name.png")).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private fun View.text(id: Int) = findViewById<TextView>(id)
    private fun View.shown(id: Int) = findViewById<View>(id).visibility == View.VISIBLE
    private fun View.skyBitmap() = (findViewById<ImageView>(R.id.skyImage).drawable as BitmapDrawable).bitmap

    /** لون السماء قرب أعلى اللوحة، بعيداً عن الزاويتين المستديرتين. */
    private fun Bitmap.skyTop() = getPixel(width / 2, height / 12)

    @Test
    fun daytime_blueSky_sunGlyph_andOnlyTheComingSunset() {
        val shot = render("1_morning", at(11, 9, 30))
        val big = shot.big

        assertTrue(big.shown(R.id.skyFrame))
        val top = big.skyBitmap().skyTop()
        assertTrue("نهار: السماء زرقاء", Color.blue(top) > 180 && Color.blue(top) > Color.red(top) + 60)

        // موعد واحد: الغروب القادم، عند طرف الغرب (يمين الراصد في نصف الكرة الشمالي)
        assertTrue(big.shown(R.id.skyLabelRight))
        assertTrue(!big.shown(R.id.skyLabelLeft))
        assertTrue(big.text(R.id.skyLabelRight).text.startsWith("الغروب 6:0"))

        // الصلاة والعدّاد والمواقيت الستة باقية
        assertEquals("أذان الظهر", big.text(R.id.bigTitle).text.toString())
        assertTrue(big.shown(R.id.bigCountdown))
        assertEquals("الفجر", big.text(R.id.cell0Name).text.toString())
        assertEquals("العشاء", big.text(R.id.cell5Name).text.toString())

        assertTrue("قرص الشمس بجانب اسم الصلاة", shot.small.shown(R.id.smallGlyph))
        assertEquals("أذان الظهر", shot.small.text(R.id.smallTitle).text.toString())
    }

    @Test
    fun theStripKeepsItsProportions_andTheCardStaysWithinTheExpandedLimit() {
        val big = render("2_noon", at(11, 12, 10)).big
        val image = big.findViewById<ImageView>(R.id.skyImage)
        val bitmap = big.skyBitmap()
        // الصورة تأخذ ارتفاعها من عرضها: لا تمدّد، فالشمس دائرة
        assertEquals(bitmap.width.toFloat() / bitmap.height, image.width.toFloat() / image.height, 0.02f)
        // حدّ الإشعار الموسّع في أندرويد 256dp
        val density = context.resources.displayMetrics.density
        assertTrue("height ${big.height / density}dp", big.height / density < 256)
    }

    @Test
    fun aroundSunset_theHorizonGlows_thenTheLabelTurnsToSunrise() {
        val before = render("3_before_sunset", at(11, 17, 58)).big
        assertTrue(before.text(R.id.skyLabelRight).text.startsWith("الغروب"))
        val horizon = before.skyBitmap().let { it.getPixel(it.width * 9 / 10, it.height * 6 / 10) }
        assertTrue("وهج الغروب جهة الغرب", Color.red(horizon) > Color.blue(horizon))

        val after = render("4_dusk", at(11, 18, 40))
        // غربت: الموعد القادم الشروق، عند طرف الشرق
        assertTrue(after.big.shown(R.id.skyLabelLeft))
        assertTrue(!after.big.shown(R.id.skyLabelRight))
        assertTrue(after.big.text(R.id.skyLabelLeft).text.startsWith("الشروق 6:3"))
    }

    @Test
    fun night_darkSkyWithStars_andTheMoonByItsPhase() {
        val crescent = render("5_night_crescent", at(16, 19, 30))
        val top = crescent.big.skyBitmap().skyTop()
        assertTrue("ليل: السماء داكنة", Color.red(top) < 60 && Color.green(top) < 60 && Color.blue(top) < 110)
        assertTrue(track.moonUp(at(16, 19, 30)))
        assertTrue("القمر بجانب اسم الصلاة", crescent.small.shown(R.id.smallGlyph))

        render("6_night_gibbous", at(22, 22, 30))

        // ليل والقمر تحت الأفق: نجوم بلا قرص
        val moonless = at(13, 2, 0)
        assertTrue(!track.moonUp(moonless))
        val dark = render("7_night_no_moon", moonless)
        assertTrue(dark.big.shown(R.id.skyFrame))
        assertTrue(!dark.small.shown(R.id.smallGlyph))
    }

    @Test
    fun dawn_andIqamaPhase() {
        val dawn = render("8_dawn", at(12, 6, 15)).big
        assertTrue(dawn.text(R.id.skyLabelLeft).text.startsWith("الشروق"))

        val iqama = render("9_iqama", at(11, 15, 45))
        assertEquals("إقامة العصر", iqama.big.text(R.id.bigTitle).text.toString())
        assertTrue(iqama.big.shown(R.id.skyFrame))
    }

    @Test
    fun aLongCountdownAfterIsha_doesNotCutTheTimesLine() {
        // بعد إقامة العشاء: العدّ إلى الفجر بالساعات، وهو أعرض ما يبلغه العدّاد
        val big = render("10_after_isha", at(11, 19, 45)).big
        assertEquals("أذان الفجر", big.text(R.id.bigTitle).text.toString())
        val detail = big.text(R.id.bigDetail)
        assertTrue(detail.text.contains("الإقامة"))
        assertEquals("سطر الموعدين كاملاً بلا قصّ", 0, detail.layout.getEllipsisCount(0))
        assertEquals(0, big.text(R.id.bigTitle).layout.getEllipsisCount(0))
    }

    @Test
    fun withoutSkyData_theBarIsWhatItWas() {
        // نسخة سابقة من التطبيق أرسلت الجدول وحده، أو تعذّرت قراءة السماء
        val plain = render("0_no_sky", at(11, 9, 30), withSky = false)
        assertTrue(!plain.big.shown(R.id.skyFrame))
        assertTrue(!plain.small.shown(R.id.smallGlyph))
        assertEquals("أذان الظهر", plain.big.text(R.id.bigTitle).text.toString())
        assertTrue(plain.big.shown(R.id.bigCountdown))
    }
}
