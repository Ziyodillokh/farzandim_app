package com.farzandim.farzandim_child

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * "Ilova bloklangan" sahifasi dasturiy quriladi (XML resource shart emas).
 * Telefon TEMASIga qarab (tungi/kunduzgi) to'liq OQ yoki QORA fonda, mos
 * "bolakay" rasmi bilan. Tugmalar ota-ona onboardingidagi primary (ko'k "OK")
 * + secondary ("Ruxsat so'rash"). Fon TO'LIQ OPAQUE — bloklangan ilova umuman
 * ko'rinmaydi.
 *
 * LAYOUT ORIENTATSIYAGA QARAB:
 *   - Portret   — ustma-ust: rasm, sarlavha, matn, tugmalar.
 *   - Landshaft — yonma-yon: rasm CHAPDA, matn+tugmalar O'NGDA (avval
 *     landshaftda vertikal layout sig'may kesilardi).
 */
internal class BlockOverlayView(
    private val ctx: Context,
    private val texts: NativeTexts,
) {

    fun build(request: OverlayRequest, onOk: () -> Unit, onRequestAccess: () -> Unit): View {
        val isLimit = request.reason == EnforcementRules.REASON_LIMIT
        val isSchool = request.reason == EnforcementRules.REASON_SCHOOL
        val config = ctx.resources.configuration
        val isNight = (config.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val isLandscape = config.orientation == Configuration.ORIENTATION_LANDSCAPE

        // ── Tema ranglari ─────────────────────────────────────────────
        val pageBg = if (isNight) Color.parseColor("#0B0D12") else Color.WHITE
        val titleColor = if (isNight) Color.WHITE else Color.parseColor("#0F1720")
        val subColor = if (isNight) Color.parseColor("#98A2B3") else Color.parseColor("#667085")
        val primaryBlue = Color.parseColor("#216BFF")
        val secondaryBg = if (isNight) Color.parseColor("#232936") else Color.parseColor("#EEF0F3")
        val secondaryText = if (isNight) Color.parseColor("#E6EAF2") else Color.parseColor("#3A4150")
        val imgName = if (isNight) "bolakay_dark" else "bolakay_light"

        val root = FrameLayout(ctx).apply { setBackgroundColor(pageBg) }

        val image = ImageView(ctx).apply {
            val id = ctx.resources.getIdentifier(imgName, "drawable", ctx.packageName)
            if (id != 0) setImageResource(id)
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
        }

        // Landshaftda matn CHAPGA (rasm yonida ustun), portretda MARKAZDA.
        val textGravity = if (isLandscape) Gravity.START else Gravity.CENTER

        val title = TextView(ctx).apply {
            text = when {
                isLimit -> texts.get("limitReached", "Bugungi vaqt tugadi")
                isSchool -> texts.get("schoolTitle", "Dars vaqti")
                else -> texts.get("blocked", "Ilova bloklangan")
            }
            setTextColor(titleColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (isLandscape) 22f else 26f)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            gravity = textGravity
            setPadding(0, if (isLandscape) 0 else dp(24), 0, dp(10))
        }

        val subtitle = TextView(ctx).apply {
            text = subtitleText(isLimit, isSchool, request.schoolUntil)
            setTextColor(subColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = textGravity
            setLineSpacing(dp(4).toFloat(), 1f)
        }

        // ── Tugmalar qatori: [OK ko'k] [Ruxsat so'rash kulrang] ──────
        val buttonRow = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL }
        buttonRow.addView(
            makeButton(texts.get("ok", "OK"), primaryBlue, Color.WHITE, onOk),
            LinearLayout.LayoutParams(0, dp(56), 1f),
        )
        // Maktab bloki ota-onadan so'rab ochilmaydi — faqat "OK".
        if (!isSchool) {
            buttonRow.addView(
                makeButton(
                    texts.get("requestAccess", "Ruxsat so'rash"),
                    secondaryBg,
                    secondaryText,
                    onRequestAccess,
                ),
                LinearLayout.LayoutParams(0, dp(56), 1f).apply { marginStart = dp(12) },
            )
        }

        val content = if (isLandscape) {
            landscape(image, title, subtitle, buttonRow)
        } else {
            portrait(image, title, subtitle, buttonRow)
        }
        root.addView(
            content,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        return root
    }

    private fun subtitleText(isLimit: Boolean, isSchool: Boolean, schoolUntil: String): String =
        when {
            isLimit -> texts.get(
                "limitSub",
                "Bu ilova uchun bugungi vaqting tugadi.\nKo'proq vaqt uchun ota-onangdan so'ra.",
            )
            isSchool && schoolUntil.isEmpty() ->
                texts.get("schoolSubNoTime", "Maktab dars vaqtida bu ilovani cheklagan.")
            isSchool -> texts.get(
                "schoolSub",
                "Maktab dars vaqtida bu ilovani cheklagan.\n{time} dan keyin ochiladi.",
            ).replace("{time}", schoolUntil)
            else -> texts.get(
                "blockedSub",
                "Bu ilovadan foydalanish hozircha cheklangan.\n" +
                    "Ruxsat olish uchun ota-onangizga murojaat qiling.",
            )
        }

    /** Portret: ustma-ust — rasm, sarlavha, matn, (bo'sh joy), tugmalar. */
    private fun portrait(image: ImageView, title: TextView, subtitle: TextView, buttons: LinearLayout): View {
        val col = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            // Yuqorida status bar, pastda navigatsiya paneli uchun joy.
            setPadding(dp(28), dp(56), dp(28), dp(40))
        }
        col.addView(View(ctx), LinearLayout.LayoutParams(0, 0, 1.1f))
        col.addView(image, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(190)))
        col.addView(title)
        col.addView(subtitle, matchWidth())
        // Pastki bo'sh joy — tugmalarni ekran pastiga suradi.
        col.addView(View(ctx), LinearLayout.LayoutParams(0, 0, 1.5f))
        col.addView(buttons, matchWidth())
        return col
    }

    /** Landshaft: rasm CHAPDA (balandlikni to'ldiradi), matn+tugmalar O'NGDA. */
    private fun landscape(image: ImageView, title: TextView, subtitle: TextView, buttons: LinearLayout): View {
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(32), dp(20), dp(32), dp(20))
        }
        row.addView(image, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f))
        val textCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
        }
        textCol.addView(title, matchWidth())
        textCol.addView(subtitle, matchWidth())
        textCol.addView(buttons, matchWidth().apply { topMargin = dp(20) })
        row.addView(
            textCol,
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.15f)
                .apply { marginStart = dp(28) },
        )
        return row
    }

    private fun matchWidth() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
    )

    /** Onboarding uslubidagi tekis, dumaloq-burchak tugma (soyasiz). */
    private fun makeButton(label: String, bgColor: Int, textColor: Int, onClick: () -> Unit): Button =
        Button(ctx).apply {
            text = label
            setTextColor(textColor)
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            minWidth = 0
            minimumWidth = 0
            minHeight = 0
            minimumHeight = 0
            setPadding(dp(10), 0, dp(10), 0)
            stateListAnimator = null
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(bgColor)
            }
            setOnClickListener { onClick() }
        }

    private fun dp(value: Int): Int = (value * ctx.resources.displayMetrics.density).toInt()
}
