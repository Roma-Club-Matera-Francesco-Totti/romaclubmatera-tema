package it.romaclubmatera.tema

import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.LauncherApps
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.os.UserHandle
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

/**
 * La Home del Club: un launcher vero (categoria HOME), disegnato in Flutter
 * (entrypoint "home" in lib/home.dart) sopra lo sfondo del telefono.
 * Le icone sono quelle originali delle app, ritagliate dentro la cornice
 * del Club.
 * I widget delle altre app vivono qui (AppWidgetHost) e Flutter li mostra
 * come viste native "rcm/widget".
 */
class HomeActivity : FlutterActivity() {

    private lateinit var canale: MethodChannel
    private val la by lazy { getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps }


    private val awm by lazy { AppWidgetManager.getInstance(this) }
    private val host by lazy { AppWidgetHost(applicationContext, HOST_ID) }
    // il widget che si sta aggiungendo: aspetta il permesso e la configurazione
    private var inAttesa: MethodChannel.Result? = null
    private var widgetInAttesa = 0

    private val avvisi = object : LauncherApps.Callback() {
        private fun cambiate() = runOnUiThread { canale.invokeMethod("cambiate", null) }
        override fun onPackageAdded(p: String, u: UserHandle) = cambiate()
        override fun onPackageRemoved(p: String, u: UserHandle) = cambiate()
        override fun onPackageChanged(p: String, u: UserHandle) = cambiate()
        override fun onPackagesAvailable(p: Array<out String>, u: UserHandle, r: Boolean) = cambiate()
        override fun onPackagesUnavailable(p: Array<out String>, u: UserHandle, r: Boolean) = cambiate()
    }

    override fun getDartEntrypointFunctionName() = "home"
    override fun getBackgroundMode() = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory("rcm/widget", Fabbrica())
        canale = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rcm/home")
        canale.setMethodCallHandler { call, result ->
            when (call.method) {
                "app" -> thread {
                    val lista = la.getActivityList(null, Process.myUserHandle())
                        .filter { it.componentName.packageName != packageName || it.name == MainActivity::class.java.name }
                        .map {
                            mapOf("pacchetto" to it.componentName.packageName, "attivita" to it.componentName.className,
                                "nome" to it.label.toString())
                        }
                    runOnUiThread { result.success(lista) }
                }
                "icona" -> {
                    val c = ComponentName(call.argument<String>("pacchetto")!!, call.argument<String>("attivita")!!)
                    thread {
                        val png = try { icona(c) } catch (e: Exception) { null }
                        runOnUiThread { result.success(png) }
                    }
                }
                "avvia" -> {
                    val c = ComponentName(call.argument<String>("pacchetto")!!, call.argument<String>("attivita")!!)
                    try { la.startMainActivity(c, Process.myUserHandle(), null, null); result.success(true) }
                    catch (e: Exception) { result.success(false) }
                }
                "info" -> {
                    val c = ComponentName(call.argument<String>("pacchetto")!!, call.argument<String>("attivita")!!)
                    la.startAppDetailsActivity(c, Process.myUserHandle(), null, null)
                    result.success(true)
                }
                "disinstalla" -> {
                    startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:" + call.argument<String>("pacchetto"))))
                    result.success(true)
                }
                // le scorciatoie dell'app (tieni premuto): solo il launcher predefinito le vede
                "scorciatoie" -> thread {
                    val lista = try {
                        val q = LauncherApps.ShortcutQuery().setPackage(call.argument<String>("pacchetto"))
                            .setActivity(ComponentName(call.argument<String>("pacchetto")!!, call.argument<String>("attivita")!!))
                            .setQueryFlags(LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                                LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST or LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED)
                        (la.getShortcuts(q, Process.myUserHandle()) ?: emptyList())
                            .filter { it.isEnabled }
                            .sortedWith(compareBy({ !it.isDeclaredInManifest }, { it.rank }))
                            .take(5)
                            .map { sc ->
                                mapOf("id" to sc.id, "nome" to (sc.shortLabel ?: sc.longLabel ?: "").toString(),
                                    "icona" to la.getShortcutIconDrawable(sc, resources.displayMetrics.densityDpi)?.let { png(it, 96) })
                            }
                    } catch (e: Exception) { emptyList() }
                    runOnUiThread { result.success(lista) }
                }
                "avviaScorciatoia" -> {
                    try {
                        la.startShortcut(call.argument<String>("pacchetto")!!, call.argument<String>("id")!!, null, null, Process.myUserHandle())
                        result.success(true)
                    } catch (e: Exception) { result.success(false) }
                }
                // pallini: quali app hanno notifiche (solo i nomi dei pacchetti, mai il contenuto)
                "pallini" -> result.success(mapOf("permesso" to Notifiche.permesso(this), "app" to Notifiche.ultime.toList()))
                "permessoPallini" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }
                // scorrendo verso il basso sulla Home si apre il pannello, come su ogni Home
                "notifiche" -> {
                    try {
                        val sb = getSystemService("statusbar")
                        Class.forName("android.app.StatusBarManager").getMethod("expandNotificationsPanel").invoke(sb)
                        result.success(true)
                    } catch (e: Exception) { result.success(false) }
                }
                "sceltaHome" -> { startActivity(Intent(Settings.ACTION_HOME_SETTINGS)); result.success(true) }
                // la scelta dello sfondo del telefono: galleria, sfondi di sistema...
                "sfondoTuo" -> {
                    startActivity(Intent.createChooser(Intent(Intent.ACTION_SET_WALLPAPER), "Scegli lo sfondo"))
                    result.success(true)
                }
                "temaRcm" -> { startActivity(Intent(this, MainActivity::class.java)); result.success(true) }
                "leggi" -> result.success(getSharedPreferences("home", MODE_PRIVATE).getString(call.argument<String>("chiave"), null))
                "scrivi" -> {
                    getSharedPreferences("home", MODE_PRIVATE).edit()
                        .putString(call.argument<String>("chiave"), call.argument<String>("valore")).apply()
                    result.success(true)
                }
                "widgetDisponibili" -> thread {
                    val d = resources.displayMetrics.density
                    // solo quelli per la Home (non schermo esterno o schermata di blocco)
                    val lista = awm.getInstalledProvidersForProfile(Process.myUserHandle())
                        .filter { it.widgetCategory and AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN != 0 }
                        .map { i ->
                        val app = try {
                            packageManager.getApplicationLabel(packageManager.getApplicationInfo(i.provider.packageName, 0)).toString()
                        } catch (e: Exception) { i.provider.packageName }
                        val descrizione = if (Build.VERSION.SDK_INT >= 31) i.loadDescription(this)?.toString() else null
                        mapOf("provider" to i.provider.flattenToString(), "nome" to i.loadLabel(packageManager), "app" to app,
                            "descrizione" to descrizione, "classe" to i.provider.className.substringAfterLast('.'),
                            "minW" to (i.minWidth / d).toDouble(), "minH" to (i.minHeight / d).toDouble(),
                            "celleW" to (if (Build.VERSION.SDK_INT >= 31) i.targetCellWidth else 0),
                            "celleH" to (if (Build.VERSION.SDK_INT >= 31) i.targetCellHeight else 0))
                    }
                    runOnUiThread { result.success(lista) }
                }
                // le viste si disegnano sul thread principale
                "anteprimaWidget" -> result.success(try { anteprima(call.argument<String>("provider")!!) } catch (e: Exception) { null })
                "aggiungiWidget" -> {
                    val cn = ComponentName.unflattenFromString(call.argument<String>("provider")!!)!!
                    inAttesa?.success(null)
                    inAttesa = result
                    widgetInAttesa = host.allocateAppWidgetId()
                    if (awm.bindAppWidgetIdIfAllowed(widgetInAttesa, cn)) configura()
                    else startActivityForResult(Intent(AppWidgetManager.ACTION_APPWIDGET_BIND)
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetInAttesa)
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, cn), RQ_PERMESSO)
                }
                // le impostazioni del widget (citta' del meteo, trasparenza...), se ne ha
                "configuraWidget" -> {
                    val id = call.argument<Int>("id")!!
                    val i = awm.getAppWidgetInfo(id)
                    if (i?.configure == null) result.success(false) else try {
                        host.startAppWidgetConfigureActivityForResult(this, id, 0, RQ_RICONFIGURA, null)
                        result.success(true)
                    } catch (e: Exception) { result.success(false) }
                }
                // collegamenti che le app hanno chiesto di fissare (PinActivity)
                "nuove" -> {
                    val p = getSharedPreferences("home", MODE_PRIVATE)
                    val l = p.getString("nuove", null)
                    p.edit().remove("nuove").apply()
                    result.success(l)
                }
                "iconaScorciatoia" -> thread {
                    val png = try {
                        val q = LauncherApps.ShortcutQuery().setPackage(call.argument<String>("pacchetto"))
                            .setShortcutIds(listOf(call.argument<String>("id")!!))
                            .setQueryFlags(LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED)
                        la.getShortcuts(q, Process.myUserHandle())?.firstOrNull()
                            ?.let { la.getShortcutIconDrawable(it, resources.displayMetrics.densityDpi) }
                            ?.let { d ->
                                val bmp = Bitmap.createBitmap(192, 192, Bitmap.Config.ARGB_8888)
                                cornice(Canvas(bmp), 192f, d)
                                ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
                            }
                    } catch (e: Exception) { null }
                    runOnUiThread { result.success(png) }
                }
                "cancella" -> { getSharedPreferences("home", MODE_PRIVATE).edit().remove(call.argument<String>("chiave")).apply(); result.success(true) }
                "rimuoviWidget" -> { host.deleteAppWidgetId(call.argument<Int>("id")!!); result.success(true) }
                // all'avvio: via i widget rimasti appesi (tolti dalla Home, aggiunte interrotte)
                "pulisciWidget" -> {
                    val usati = call.argument<List<Int>>("usati")!!.toSet()
                    host.appWidgetIds.filter { it !in usati }.forEach { host.deleteAppWidgetId(it) }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        la.registerCallback(avvisi)
        nuove = { runOnUiThread { if (::canale.isInitialized) canale.invokeMethod("nuove", null) } }
        Notifiche.ascolta = { app -> runOnUiThread { if (::canale.isInitialized) canale.invokeMethod("pallini", app.toList()) } }
    }

    override fun onStart() {
        super.onStart()
        host.startListening()
    }

    override fun onStop() {
        super.onStop()
        host.stopListening()
    }

    override fun onDestroy() {
        nuove = null
        Notifiche.ascolta = null
        la.unregisterCallback(avvisi)
        super.onDestroy()
    }

    // il tasto Home premuto mentre siamo gia' qui: si torna alla prima schermata
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (::canale.isInitialized) canale.invokeMethod("home", null)
    }

    @Deprecated("startActivityForResult: qui basta")
    override fun onActivityResult(richiesta: Int, esito: Int, dati: Intent?) {
        super.onActivityResult(richiesta, esito, dati)
        when (richiesta) {
            RQ_PERMESSO -> if (esito == RESULT_OK) configura() else finito(false)
            RQ_CONFIGURA -> finito(esito == RESULT_OK)
        }
    }

    private fun info(provider: String): AppWidgetProviderInfo? {
        val cn = ComponentName.unflattenFromString(provider) ?: return null
        return awm.getInstalledProvidersForProfile(Process.myUserHandle()).firstOrNull { it.provider == cn }
    }

    /**
     * L'anteprima per la scelta: quella generata (Android 15), poi il layout
     * di anteprima (Android 12, come fa Samsung), poi l'immagine, poi l'icona.
     */
    private fun anteprima(provider: String): ByteArray? {
        val i = info(provider) ?: return null
        val d = resources.displayMetrics.density
        val vista: RemoteViews? = when {
            Build.VERSION.SDK_INT >= 35 -> try {
                awm.getWidgetPreview(i.provider, Process.myUserHandle(), AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN)
            } catch (e: Exception) { null }
            else -> null
        } ?: if (Build.VERSION.SDK_INT >= 31 && i.previewLayout != 0) RemoteViews(i.provider.packageName, i.previewLayout) else null
        if (vista != null) {
            try {
                val w = maxOf(i.minWidth, (110 * d).toInt()); val h = maxOf(i.minHeight, (110 * d).toInt())
                val v = vista.apply(this, FrameLayout(this))
                v.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
                v.layout(0, 0, w, h)
                val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                v.draw(Canvas(bmp))
                val k = minOf(1f, 360f / maxOf(w, h))
                val piccola = Bitmap.createScaledBitmap(bmp, maxOf(1, (w * k).toInt()), maxOf(1, (h * k).toInt()), true)
                return ByteArrayOutputStream().also { piccola.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
            } catch (e: Exception) { }
        }
        return (i.loadPreviewImage(this, 0) ?: i.loadIcon(this, 0))?.let { png(it, 360) }
    }

    // alcuni widget vogliono essere configurati (citta' del meteo, contatto...)
    private fun configura() {
        val i = awm.getAppWidgetInfo(widgetInAttesa)
        val facoltativa = Build.VERSION.SDK_INT >= 31 &&
            (i?.widgetFeatures ?: 0) and AppWidgetProviderInfo.WIDGET_FEATURE_CONFIGURATION_OPTIONAL != 0
        if (i?.configure != null && !facoltativa) {
            try {
                host.startAppWidgetConfigureActivityForResult(this, widgetInAttesa, 0, RQ_CONFIGURA, null)
                return
            } catch (e: Exception) { }
        }
        finito(true)
    }

    private fun finito(ok: Boolean) {
        if (!ok) host.deleteAppWidgetId(widgetInAttesa)
        inAttesa?.success(if (ok) widgetInAttesa else null)
        inAttesa = null
    }

    /** Il widget come vista nativa; si ridimensiona con la casella della Home. */
    private inner class Fabbrica : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            val m = args as Map<*, *>
            val id = (m["id"] as Number).toInt()
            // lato della casella della Home in dp: i widget Samsung vogliono le caselle occupate
            val celle = ((m["cw"] as? Number)?.toFloat() ?: 90f) to ((m["ch"] as? Number)?.toFloat() ?: 110f)
            val i = awm.getAppWidgetInfo(id)
            val v: View = if (i == null) TextView(this@HomeActivity).apply {
                text = "Widget non disponibile"; setTextColor(Color.WHITE); gravity = Gravity.CENTER
            } else host.createView(this@HomeActivity, id, i).apply {
                // il margine lo mette la Home (Flutter): cosi' il ritaglio tondo cade sul widget
                setPadding(0, 0, 0, 0)
                addOnLayoutChangeListener { _, l, t, r, b, ol, ot, or_, ob ->
                    if (r - l > 0 && b - t > 0 && (r - l != or_ - ol || b - t != ob - ot)) dimensioni(id, r - l, b - t, celle)
                }
            }
            val tonda = Tonda(this@HomeActivity).apply { addView(v) }
            return object : PlatformView {
                override fun getView() = tonda
                override fun dispose() {}
            }
        }
    }

    /**
     * Dice al widget quanto e' grande: l'elenco delle dimensioni (Android 12+:
     * i widget con piu' layout scelgono da li', vuoto = il piu' povero) e le
     * opzioni che passa la Home Samsung (stile One UI, tema scuro, caselle):
     * senza, il meteo Samsung non e' trasparente e non sa quante caselle ha.
     */
    private fun dimensioni(id: Int, wPx: Int, hPx: Int, celle: Pair<Float, Float>) {
        val d = resources.displayMetrics.density
        val w = wPx / d; val h = hPx / d
        val o = awm.getAppWidgetOptions(id) ?: Bundle()
        o.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, w.toInt())
        o.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, w.toInt())
        o.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, h.toInt())
        o.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, h.toInt())
        if (Build.VERSION.SDK_INT >= 31) {
            o.putParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES, arrayListOf(android.util.SizeF(w, h)))
        }
        val col = maxOf(1, Math.round(w / celle.first)); val righe = maxOf(1, Math.round(h / celle.second))
        val notte = resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
        o.putString("hsMode", "OneUI")
        o.putInt("semHostType", 1)
        o.putInt("semWidgetStyle", 1)
        o.putInt("semAppWidgetColumnSpan", col)
        o.putInt("semAppWidgetRowSpan", righe)
        o.putInt("darkModeStatus", notte)
        o.putFloat("semShapeRadius", 22f)
        o.putFloat("semDisplayDensity", d)
        o.putFloat("semFontScale", resources.configuration.fontScale)
        o.putBoolean("semIsWallpaperBlurSupported", true)
        o.putBoolean("hsWidgetLabelEnabled", false)
        o.putFloat("hsResizeRatio", 1f)
        try { awm.updateAppWidgetOptions(id, o) } catch (e: Exception) { }
    }

    /**
     * Angoli tondi come i widget di Android 12, anche per chi non li ha.
     * Ritaglio a mano: la vista finisce su una superficie di Flutter, dove
     * clipToOutline non vale.
     */
    private class Tonda(c: Context) : FrameLayout(c) {
        private val raggio = 22 * c.resources.displayMetrics.density
        private val forma = android.graphics.Path()

        override fun onSizeChanged(w: Int, h: Int, ow: Int, oh: Int) {
            super.onSizeChanged(w, h, ow, oh)
            forma.reset()
            forma.addRoundRect(0f, 0f, w.toFloat(), h.toFloat(), raggio, raggio, android.graphics.Path.Direction.CW)
        }

        override fun dispatchDraw(c: Canvas) {
            val n = c.save()
            c.clipPath(forma)
            super.dispatchDraw(c)
            c.restoreToCount(n)
        }
    }

    private fun icona(c: ComponentName): ByteArray {
        val lato = 192
        val bmp = Bitmap.createBitmap(lato, lato, Bitmap.Config.ARGB_8888)
        val tela = Canvas(bmp)
        // dalla 1.5.3 tutte le app con la loro icona nel bordino del Club
        // (Michele, 10/10/2026: "le icone originali con il bordino sono piu' belle");
        // le icone disegnate restano nel pacchetto per Theme Park e gli altri launcher
        val orig = la.getActivityList(c.packageName, Process.myUserHandle())
            .firstOrNull { it.componentName == c }?.getIcon(0)
            ?: packageManager.getApplicationIcon(c.packageName)
        cornice(tela, lato.toFloat(), orig)
        return ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }

    /**
     * Come personale/cornice.py: tondo rosso sfumato, l'icona originale
     * ritagliata a cerchio, filetto oro. Le icone adattive si disegnano a
     * strati, senza la forma del telefono: niente quadrati bianchi attorno.
     */
    private fun cornice(tela: Canvas, l: Float, orig: Drawable) {
        val c = l / 2
        val u = l / 192 // misure pensate su 192 px
        val r = 92 / 96f * c
        val fondo = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            shader = android.graphics.RadialGradient(c, .76f * c, 1.4f * c,
                Color.rgb(0xa8, 0x22, 0x34), Color.rgb(0x5a, 0x0f, 0x19), android.graphics.Shader.TileMode.CLAMP)
        }
        tela.drawCircle(c, c, r, fondo)
        val ri = 72 / 96f * c
        val n = tela.save()
        tela.clipPath(android.graphics.Path().apply { addCircle(c, c, ri, android.graphics.Path.Direction.CW) })
        if (orig is android.graphics.drawable.AdaptiveIconDrawable) {
            // la parte visibile di un'icona adattiva e' i 2/3 centrali
            val m = (ri * 1.5f).toInt()
            for (s in listOf(orig.background, orig.foreground)) {
                s?.setBounds((c - m).toInt(), (c - m).toInt(), (c + m).toInt(), (c + m).toInt()); s?.draw(tela)
            }
        } else {
            tela.drawColor(Color.rgb(0xf6, 0xec, 0xd0)) // icone trasparenti: fondo panna
            orig.setBounds((c - ri).toInt(), (c - ri).toInt(), (c + ri).toInt(), (c + ri).toInt()); orig.draw(tela)
        }
        tela.restoreToCount(n)
        val rr = 78 / 96f * c
        for ((w, col) in listOf(5.5f to Color.rgb(0xb8, 0x86, 0x1a), 3.5f to Color.rgb(0xe3, 0xad, 0x1e), 1.2f to Color.rgb(0xf6, 0xcf, 0x5a))) {
            tela.drawCircle(c, c, rr, android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                style = android.graphics.Paint.Style.STROKE; strokeWidth = w * u; color = col
            })
        }
    }

    private fun png(d: Drawable, max: Int): ByteArray {
        val w0 = d.intrinsicWidth.takeIf { it > 0 } ?: max
        val h0 = d.intrinsicHeight.takeIf { it > 0 } ?: max
        val k = minOf(1f, max.toFloat() / maxOf(w0, h0))
        val w = maxOf(1, (w0 * k).toInt()); val h = maxOf(1, (h0 * k).toInt())
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, w, h); d.draw(Canvas(bmp))
        return ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }

    companion object {
        const val HOST_ID = 0x52434D
        const val RQ_PERMESSO = 71
        const val RQ_CONFIGURA = 72
        const val RQ_RICONFIGURA = 73
        /** PinActivity avvisa la Home quando arriva un collegamento nuovo. */
        var nuove: (() -> Unit)? = null
    }
}
