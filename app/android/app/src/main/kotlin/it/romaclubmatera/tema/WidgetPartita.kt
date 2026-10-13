package it.romaclubmatera.tema

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.concurrent.thread

/**
 * Widget "Prossima partita". Il calendario arriva da
 * romaclubmatera.it/wp-json/rcm/v1/prossime (pubblico, nessun dato
 * dell'utente) e resta in cache: si rilegge al massimo ogni 3 ore, o prima
 * se la partita in cima e' finita. Il "fra N giorni" si ricalcola a ogni
 * aggiornamento del sistema (30 minuti, widget_partita_info.xml).
 */
class WidgetPartita : AppWidgetProvider() {

    companion object {
        private const val URL_PROSSIME = "https://romaclubmatera.it/wp-json/rcm/v1/prossime"
        private const val RILEGGI_MS = 3 * 60 * 60 * 1000L
        private const val DURATA_MIN = 120L
        private val ITALIA = Locale.ITALIAN

        /** Ridisegna tutti i widget, per esempio appena aggiunto dall'app. */
        fun aggiorna(ctx: Context) {
            val am = AppWidgetManager.getInstance(ctx)
            val ids = am.getAppWidgetIds(ComponentName(ctx, WidgetPartita::class.java))
            if (ids.isNotEmpty()) {
                ctx.sendBroadcast(Intent(ctx, WidgetPartita::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids))
            }
        }
    }

    override fun onUpdate(ctx: Context, am: AppWidgetManager, ids: IntArray) {
        val attesa = goAsync()
        thread {
            try {
                val partite = partite(ctx)
                for (id in ids) am.updateAppWidget(id, vista(ctx, partite))
            } finally {
                attesa.finish()
            }
        }
    }

    /** Le partite non ancora finite: dalla cache, o dal sito se serve. */
    private fun partite(ctx: Context): List<JSONObject> {
        val prefs = ctx.getSharedPreferences("widget", Context.MODE_PRIVATE)
        val letto = prefs.getLong("letto", 0)
        var dati = prefs.getString("prossime", null)
        val vecchie = dati == null || System.currentTimeMillis() - letto > RILEGGI_MS || daGiocare(dati).isEmpty()
        if (vecchie) {
            scarica()?.let {
                dati = it
                prefs.edit().putString("prossime", it).putLong("letto", System.currentTimeMillis()).apply()
            }
        }
        return dati?.let { daGiocare(it) } ?: emptyList()
    }

    private fun scarica(): String? = try {
        val c = URL(URL_PROSSIME).openConnection() as HttpURLConnection
        c.connectTimeout = 8000
        c.readTimeout = 8000
        c.setRequestProperty("Accept", "application/json")
        try {
            if (c.responseCode == 200) c.inputStream.bufferedReader().readText().also { JSONObject(it) } else null
        } finally {
            c.disconnect()
        }
    } catch (e: Exception) {
        null
    }

    private fun daGiocare(json: String): List<JSONObject> = try {
        val a: JSONArray = JSONObject(json).getJSONArray("partite")
        val adesso = OffsetDateTime.now()
        (0 until a.length()).map { a.getJSONObject(it) }.filter {
            OffsetDateTime.parse(it.getString("quando")).plusMinutes(DURATA_MIN).isAfter(adesso)
        }
    } catch (e: Exception) {
        emptyList()
    }

    private fun vista(ctx: Context, partite: List<JSONObject>): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_partita)
        val p = partite.firstOrNull()
        if (p == null) {
            v.setTextViewText(R.id.competizione, "Prossima partita")
            v.setTextViewText(R.id.squadre, "Roma Club Matera")
            v.setTextViewText(R.id.quando, "Calendario non disponibile: tocca per riprovare")
            // un tocco chiede subito un nuovo aggiornamento
            val i = Intent(ctx, WidgetPartita::class.java).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, AppWidgetManager.getInstance(ctx)
                    .getAppWidgetIds(ComponentName(ctx, WidgetPartita::class.java)))
            v.setOnClickPendingIntent(R.id.radice, PendingIntent.getBroadcast(ctx, 0, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            return v
        }
        val quando = OffsetDateTime.parse(p.getString("quando")).atZoneSameInstant(ZoneId.systemDefault())
        val ora = p.optString("ora")
        val giorno = quando.format(DateTimeFormatter.ofPattern("EEEE d MMMM", ITALIA)).replaceFirstChar { it.titlecase(ITALIA) }
        // tre righe, cosi' sta in una riga della Home: quanto manca e competizione,
        // squadre, giorno con ora e canale
        val competizione = p.optString("competizione")
        v.setTextViewText(R.id.competizione,
            manca(quando.toOffsetDateTime(), ora.isNotEmpty()) + if (competizione.isNotEmpty()) " · $competizione" else "")
        v.setTextViewText(R.id.squadre, "${p.getString("casa")} – ${p.getString("ospiti")}")
        val tv = p.optString("tv")
        v.setTextViewText(R.id.quando, (if (ora.isEmpty()) "$giorno · orario da definire" else "$giorno · $ora") +
            if (tv.isNotEmpty()) " · $tv" else "")
        p.optString("pagina").takeIf { it.startsWith("https://") }?.let {
            v.setOnClickPendingIntent(R.id.radice, PendingIntent.getActivity(ctx, 1,
                Intent(Intent.ACTION_VIEW, Uri.parse(it)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }
        return v
    }

    /** "Si gioca!", "Oggi", "Domani", "Fra 4 giorni". */
    private fun manca(inizio: OffsetDateTime, oraNota: Boolean): String {
        val adesso = OffsetDateTime.now()
        if (oraNota && !adesso.isBefore(inizio)) return "Si gioca!"
        val giorni = ChronoUnit.DAYS.between(LocalDate.now(), inizio.atZoneSameInstant(ZoneId.systemDefault()).toLocalDate())
        return when {
            giorni <= 0L -> "Oggi"
            giorni == 1L -> "Domani"
            else -> "Fra $giorni giorni"
        }
    }
}
