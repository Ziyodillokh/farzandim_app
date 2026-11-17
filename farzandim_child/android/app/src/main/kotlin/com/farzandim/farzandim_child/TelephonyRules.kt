package com.farzandim.farzandim_child

/**
 * Qo'ng'iroq xavfsizligi qoidalari — sof Kotlin (JVM testlanadi).
 * Android qismi: [TelephonyGuard].
 *
 * Muammo (fn-wildcard-blocks-calls): "Barcha ilovalarni bloklash" ('*')
 * qulflangan ekrandagi kiruvchi qo'ng'iroq ekranini va favqulodda terish
 * oynasini overlay bilan yopardi — bola ota-onasining qo'ng'irog'ini qabul
 * qila olmas va 112/103 ga tera olmasdi.
 */
object TelephonyRules {

    /** Doim ruxsat etilgan telefon/telecom paketlari (qo'ng'iroq UI, favqulodda terish). */
    val KNOWN_PACKAGES: Set<String> = setOf(
        "com.android.phone", // AOSP telefon + EmergencyDialer
        "com.android.server.telecom",
        "com.android.incallui",
        "com.samsung.android.incallui",
        "com.google.android.dialer",
    )

    // android.media.AudioManager konstantalari (ommaviy API).
    const val MODE_NORMAL = 0
    const val MODE_RINGTONE = 1
    const val MODE_IN_CALL = 2
    const val MODE_IN_COMMUNICATION = 3
    const val MODE_CALL_SCREENING = 4
    const val MODE_CALL_REDIRECT = 5
    const val MODE_COMMUNICATION_REDIRECT = 6

    /**
     * Telefon ilovalari to'plami: standart va tizim teruvchisi, ACTION_DIAL'ni
     * ochadigan TIZIM ilovalari va ma'lum qo'ng'iroq UI paketlari. Uchinchi
     * tomon DIAL ilovalari faqat standart teruvchi bo'lsa qo'shiladi — aks
     * holda istalgan ilova DIAL e'lon qilib blokdan qochib qolardi.
     */
    fun allowSet(
        defaultDialer: String?,
        systemDialer: String?,
        systemDialHandlers: Collection<String>,
    ): Set<String> {
        val out = HashSet(KNOWN_PACKAGES)
        if (!defaultDialer.isNullOrBlank()) out += defaultDialer
        if (!systemDialer.isNullOrBlank()) out += systemDialer
        systemDialHandlers.filterTo(out) { it.isNotBlank() }
        return out
    }

    /**
     * Qo'ng'iroq paytida blok overlay ko'rsatilmaydi (ko'rinib tursa —
     * yopiladi) — faqat oddiy (GSM/telefon) qo'ng'iroq jiringlashi va suhbati.
     *
     * VoIP (MODE_IN_COMMUNICATION) ataylab KIRMAYDI: audio rejimi butun
     * qurilmaniki va istalgan ilova (Telegram/Discord ovozli chati, brauzer
     * WebRTC) uni yoqa oladi — shunda dars/uyqu bloki BOSHQA ilovalar uchun
     * ham o'chib qolardi (aylanib o'tish yo'li). Qo'ng'iroq UI va teruvchi
     * [allowSet] orqali doim ochiq, shuning uchun ota-onaning telefon
     * qo'ng'irog'i baribir qabul qilinadi.
     */
    fun suppressOverlay(audioMode: Int): Boolean =
        when (audioMode) {
            MODE_RINGTONE, MODE_IN_CALL, MODE_CALL_SCREENING, MODE_CALL_REDIRECT -> true
            else -> false
        }
}
