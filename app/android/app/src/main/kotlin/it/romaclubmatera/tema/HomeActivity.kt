package it.romaclubmatera.tema

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.LauncherApps
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Bundle
import android.os.Process
import android.os.UserHandle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.xmlpull.v1.XmlPullParser
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

/**
 * La Home del Club: un launcher vero (categoria HOME), disegnato in Flutter
 * (entrypoint "home" in lib/home.dart) sopra lo sfondo del telefono.
 * Le icone sono quelle del tema: dal pacchetto se l'app e' in appfilter.xml,
 * altrimenti l'icona originale dentro la cornice (come fanno Nova & co.).
 */
class HomeActivity : FlutterActivity() {

    private lateinit var canale: MethodChannel
    private val la by lazy { getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps }

    // componente "pacchetto/attivita'" -> nome del drawable del tema
    private val filtro: Map<String, String> by lazy { leggiFiltro() }
    private var scala = 0.62f

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
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        la.registerCallback(avvisi)
    }

    override fun onDestroy() {
        la.unregisterCallback(avvisi)
        super.onDestroy()
    }

    // il tasto Home premuto mentre siamo gia' qui: si torna alla prima schermata
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (::canale.isInitialized) canale.invokeMethod("home", null)
    }

    private fun leggiFiltro(): Map<String, String> {
        val m = HashMap<String, String>()
        val id = resources.getIdentifier("appfilter", "xml", packageName)
        if (id == 0) return m
        val x = resources.getXml(id)
        while (x.next() != XmlPullParser.END_DOCUMENT) {
            if (x.eventType != XmlPullParser.START_TAG) continue
            when (x.name) {
                "item" -> {
                    val comp = x.getAttributeValue(null, "component") ?: continue
                    val d = x.getAttributeValue(null, "drawable") ?: continue
                    val k = comp.removePrefix("ComponentInfo{").removeSuffix("}")
                    // "pacchetto/.Attivita" -> nome completo
                    val (p, a) = k.split("/", limit = 2).let { it[0] to it.getOrElse(1) { "" } }
                    m["$p/${if (a.startsWith(".")) p + a else a}"] = d
                    m.putIfAbsent("$p/*", d) // stessa app con un'attivita' diversa
                }
                "scale" -> x.getAttributeValue(null, "factor")?.toFloatOrNull()?.let { scala = it }
            }
        }
        return m
    }

    private fun drawable(nome: String): Drawable? {
        val id = resources.getIdentifier(nome, "drawable", packageName)
        return if (id == 0) null else resources.getDrawable(id, theme)
    }

    private fun icona(c: ComponentName): ByteArray {
        val lato = 192
        val bmp = Bitmap.createBitmap(lato, lato, Bitmap.Config.ARGB_8888)
        val tela = Canvas(bmp)
        val mio = filtro["${c.packageName}/${c.className}"] ?: filtro["${c.packageName}/*"]
        val tema = mio?.let { drawable(it) }
        if (tema != null) {
            tema.setBounds(0, 0, lato, lato); tema.draw(tela)
        } else {
            drawable("rcm_cornice")?.let { it.setBounds(0, 0, lato, lato); it.draw(tela) }
            val orig = la.getActivityList(c.packageName, Process.myUserHandle())
                .firstOrNull { it.componentName == c }?.getBadgedIcon(0)
                ?: packageManager.getApplicationIcon(c.packageName)
            val l = (lato * scala).toInt(); val o = (lato - l) / 2
            orig.setBounds(o, o, o + l, o + l); orig.draw(tela)
        }
        return ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }
}
