package it.romaclubmatera.tema

import android.app.WallpaperManager
import android.content.pm.LauncherApps
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.os.Process
import java.io.File
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    companion object {
        // Su Android 12+ cambiare sfondo ricalcola i colori di sistema e
        // ricrea l'attivita': l'esito resta qui e l'app lo chiede al riavvio.
        var esito: String? = null
    }

    // Launcher che sappiamo comandare direttamente; per gli altri si apre
    // il launcher e l'app spiega dove cliccare.
    private val launcher = linkedMapOf(
        "com.teslacoilsw.launcher" to "Nova Launcher",
        "app.lawnchair" to "Lawnchair",
        "app.lawnchair.play" to "Lawnchair",
        "ginlemon.flowerfree" to "Smart Launcher",
        "ginlemon.flowerpro" to "Smart Launcher",
        "com.actionlauncher.playstore" to "Action Launcher",
        "com.samsung.android.themedesigner" to "Theme Park",
        // non e' un launcher: serve a sapere a che punto e' un Samsung
        "com.samsung.android.goodlock" to "Good Lock",
    )

    /**
     * Per il pacchetto personale (personale/genera.sh): con l'extra
     * "esporta_icone" salva l'icona originale di ogni app installata in
     * Android/data/<app>/files/icone/<pacchetto>__<attivita'>.png (288 px).
     * Restano sul telefono; le prende adb.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra("esporta_icone", false) == true) thread { esportaIcone() }
        // una disposizione della Home RCM da importare (JSON con i nomi delle app):
        // la applica la Home al prossimo avvio
        intent?.getStringExtra("importa_home")?.let {
            getSharedPreferences("home", MODE_PRIVATE).edit().putString("importa", it).apply()
        }
    }

    private fun esportaIcone() {
        val dir = File(getExternalFilesDir(null), "icone").apply { deleteRecursively(); mkdirs() }
        val la = getSystemService(LAUNCHER_APPS_SERVICE) as LauncherApps
        for (a in la.getActivityList(null, Process.myUserHandle())) {
            try {
                val d = a.getIcon(640)
                val b = Bitmap.createBitmap(288, 288, Bitmap.Config.ARGB_8888)
                d.setBounds(0, 0, 288, 288); d.draw(Canvas(b))
                File(dir, "${a.componentName.packageName}__${a.componentName.className}.png").outputStream().use {
                    b.compress(Bitmap.CompressFormat.PNG, 100, it)
                }
            } catch (e: Exception) { }
        }
        File(dir, "FATTO").writeText("ok")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rcm/tema").setMethodCallHandler { call, result ->
            when (call.method) {
                "sfondo" -> {
                    val asset = call.argument<String>("asset")!!
                    val dove = call.argument<String>("dove")!!
                    val chiave = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
                    thread {
                        try {
                            val wm = WallpaperManager.getInstance(this)
                            val flag = when (dove) {
                                "home" -> WallpaperManager.FLAG_SYSTEM
                                "blocco" -> WallpaperManager.FLAG_LOCK
                                else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                            }
                            esito = dove
                            assets.open(chiave).use { wm.setStream(it, null, true, flag) }
                            runOnUiThread { try { result.success(true) } catch (e: Exception) { } }
                        } catch (e: Exception) {
                            esito = null
                            runOnUiThread { try { result.error("sfondo", e.message, null) } catch (x: Exception) { } }
                        }
                    }
                }
                "esito" -> { result.success(esito); esito = null }
                "launcher" -> {
                    val pm = packageManager
                    val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                    val predefinito = pm.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
                    val installati = launcher.keys.filter {
                        try { pm.getPackageInfo(it, 0); true } catch (e: PackageManager.NameNotFoundException) { false }
                    }
                    result.success(mapOf("predefinito" to predefinito, "installati" to installati))
                }
                "applica" -> result.success(applica(call.argument<String>("pacchetto")!!))
                "sceltaHome" -> { startActivity(Intent(Settings.ACTION_HOME_SETTINGS)); result.success(true) }
                "apri" -> {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!)))
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** true se il launcher ha ricevuto il comando di applicare le icone,
     *  false se lo abbiamo solo aperto (l'utente sceglie a mano). */
    private fun applica(p: String): Boolean {
        val mio = packageName
        val diretto = when (p) {
            "com.teslacoilsw.launcher" -> Intent("com.teslacoilsw.launcher.APPLY_ICON_THEME").setPackage(p)
                .putExtra("com.teslacoilsw.launcher.extra.ICON_THEME_TYPE", "GO")
                .putExtra("com.teslacoilsw.launcher.extra.ICON_THEME_PACKAGE", mio)
            "ginlemon.flowerfree", "ginlemon.flowerpro" -> Intent("ginlemon.smartlauncher.setGSLTHEME").setPackage(p)
                .putExtra("package", mio)
            "com.actionlauncher.playstore" -> packageManager.getLaunchIntentForPackage(p)
                ?.putExtra("apply_icon_pack", mio)
            else -> null
        }
        if (diretto != null) {
            try {
                startActivity(diretto.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) { }
        }
        packageManager.getLaunchIntentForPackage(p)?.let { startActivity(it) }
        return false
    }
}
