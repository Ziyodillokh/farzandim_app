package com.farzandim.farzandim_child

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * RingActivity — "Baland ovoz" paytida EKRANNI UYG'OTADI va qulf ustida
 * ko'rinadi (Google Family Link / qo'ng'iroq kabi). RingService full-screen
 * intent orqali ochadi. "To'xtatish" tugmasi ringni to'xtatadi.
 *
 * Yengil (Flutter engine'siz, oddiy Activity) — qulflangan ekranda ham tez
 * ochiladi. Ovozni RingService chiqaradi; bu ekran faqat vizual + Stop.
 */
class RingActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ekranni yoqish + qulf ustida ko'rsatish.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            (getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager)
                ?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }

        setContentView(buildView())
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun buildView(): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0A0A12"))
            setPadding(dp(32), dp(32), dp(32), dp(32))
        }
        val title = TextView(this).apply {
            text = "Farzandim"
            setTextColor(Color.WHITE)
            textSize = 30f
            gravity = Gravity.CENTER
        }
        val subtitle = TextView(this).apply {
            text = "Qurilma chaqirilmoqda…"
            setTextColor(Color.parseColor("#9999A8"))
            textSize = 17f
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(40))
        }
        val stopBtn = Button(this).apply {
            text = "To'xtatish"
            setTextColor(Color.parseColor("#0A0A12"))
            setPadding(dp(24), dp(12), dp(24), dp(12))
            background = GradientDrawable().apply {
                cornerRadius = dp(28).toFloat()
                setColor(Color.parseColor("#C5F562"))
            }
            setOnClickListener {
                RingService.stop(this@RingActivity)
                finish()
            }
        }
        root.addView(title)
        root.addView(subtitle)
        root.addView(
            stopBtn,
            LinearLayout.LayoutParams(
                dp(200),
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        return root
    }
}
