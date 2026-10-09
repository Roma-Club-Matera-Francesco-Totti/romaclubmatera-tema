package it.romaclubmatera.tema

import android.app.Activity
import android.content.pm.LauncherApps
import android.os.Bundle
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

/**
 * Un'app chiede di fissare un collegamento sulla Home (un contatto da
 * Contatti, un dispositivo da SmartThings, "Fotocamera" da TikTok...):
 * Android lo chiede al launcher predefinito. Lo accettiamo e lo mettiamo in
 * coda; la Home RCM lo aggiunge nel primo posto libero.
 */
class PinActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val la = getSystemService(LauncherApps::class.java)
        val r = try { la.getPinItemRequest(intent) } catch (e: Exception) { null }
        val sc = r?.shortcutInfo
        if (r != null && r.isValid && r.requestType == LauncherApps.PinItemRequest.REQUEST_TYPE_SHORTCUT && sc != null && r.accept()) {
            val p = getSharedPreferences("home", MODE_PRIVATE)
            val l = JSONArray(p.getString("nuove", null) ?: "[]")
            l.put(JSONObject().put("pacchetto", sc.`package`).put("id", sc.id).put("nome", (sc.shortLabel ?: sc.longLabel ?: "").toString()))
            p.edit().putString("nuove", l.toString()).apply()
            HomeActivity.nuove?.invoke()
            Toast.makeText(this, "Aggiunto alla Home RCM", Toast.LENGTH_SHORT).show()
        }
        finish()
    }
}
