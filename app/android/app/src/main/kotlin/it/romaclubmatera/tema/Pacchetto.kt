package it.romaclubmatera.tema

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.LauncherApps
import android.content.pm.PackageInstaller
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Process
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.android.apksig.ApkSigner
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.cert.X509Certificate
import java.util.Date
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import javax.security.auth.x500.X500Principal

/**
 * Il pacchetto di icone per Theme Park (Samsung) costruito sul telefono di
 * chi usa l'app: ogni app installata con la sua icona nel bordino del Club.
 * Theme Park accetta solo icone gia' pronte dentro un pacchetto, e la Home
 * Samsung non si puo' tematizzare da un'app qualsiasi: cosi' anche chi
 * resta sulla Home Samsung ha il bordino su tutte le app.
 *
 * Parte dal modello (assets/pacchetto-modello.apk, pacchetto/modello.sh):
 * sostituisce i PNG segnaposto e i due XML con gli stessi nomi di file,
 * firma con una chiave che resta nel telefono (AndroidKeyStore) e installa.
 * Quando si installano app nuove si rifa' (stesso nome, stessa chiave).
 */
object Pacchetto {
    const val NOME = "it.romaclubmatera.tema.icone"
    private const val CHIAVE = "rcm_pacchetto_icone"
    private const val POSTI = 600
    private const val LATO = 192

    /** Chi aspetta l'esito dell'installazione (MainActivity). */
    var esito: ((Boolean, String?) -> Unit)? = null

    /** Costruisce e firma il pacchetto; ritorna il file e quante app ci sono. */
    fun costruisci(c: Context, avanzamento: (Int, Int) -> Unit): Pair<File, Int> {
        val la = c.getSystemService(LauncherApps::class.java)
        val app = la.getActivityList(null, Process.myUserHandle())
            .filter { it.componentName.packageName != NOME }
            .distinctBy { it.componentName }
            .take(POSTI)
        val icone = HashMap<Int, ByteArray>()
        val voci = ArrayList<Pair<String, String>>() // componente, drawable
        app.forEachIndexed { i, a ->
            avanzamento(i, app.size)
            val bmp = Bitmap.createBitmap(LATO, LATO, Bitmap.Config.ARGB_8888)
            try {
                Cornice.disegna(Canvas(bmp), LATO.toFloat(), a.getIcon(0))
            } catch (e: Exception) { return@forEachIndexed }
            icone[i] = ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
            val cn = a.componentName
            voci += "ComponentInfo{${cn.packageName}/${cn.className}}" to "p%04d".format(i)
        }
        avanzamento(app.size, app.size)

        val grezzo = File(c.cacheDir, "pacchetto-grezzo.apk")
        val firmato = File(c.cacheDir, "pacchetto.apk")
        val segnaposto = Regex("res/drawable[^/]*/p(\\d{4})\\.png")
        ZipInputStream(c.assets.open("pacchetto-modello.apk")).use { zin ->
            ZipOutputStream(FileOutputStream(grezzo)).use { zout ->
                var e = zin.nextEntry
                while (e != null) {
                    val nome = e.name
                    val orig = zin.readBytes()
                    val dati = segnaposto.matchEntire(nome)?.let { icone[it.groupValues[1].toInt()] } ?: when (nome) {
                        "res/xml/appfilter.xml" -> Axml.risorse(voci.map { listOf("component" to it.first, "drawable" to it.second) })
                        "res/xml/drawable.xml" -> Axml.risorse(voci.map { listOf("drawable" to it.second) })
                        else -> orig
                    }
                    val ze = ZipEntry(nome)
                    // resources.arsc non compresso (lo vuole Android); l'allineamento lo fa apksig
                    if (nome == "resources.arsc" || nome.endsWith(".png")) {
                        ze.method = ZipEntry.STORED
                        ze.size = dati.size.toLong(); ze.compressedSize = dati.size.toLong()
                        ze.crc = CRC32().also { it.update(dati) }.value
                    }
                    zout.putNextEntry(ze); zout.write(dati); zout.closeEntry()
                    e = zin.nextEntry
                }
            }
        }
        val (chiave, cert) = chiave()
        ApkSigner.Builder(listOf(ApkSigner.SignerConfig.Builder("rcm", chiave, listOf(cert)).build()))
            .setInputApk(grezzo).setOutputApk(firmato).setMinSdkVersion(26)
            .setV1SigningEnabled(true).setV2SigningEnabled(true).setV3SigningEnabled(false)
            .build().sign()
        grezzo.delete()
        return firmato to voci.size
    }

    /** La chiave del pacchetto: creata la prima volta, resta nel telefono. */
    private fun chiave(): Pair<PrivateKey, X509Certificate> {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!ks.containsAlias(CHIAVE)) {
            val g = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
            g.initialize(
                KeyGenParameterSpec.Builder(CHIAVE, KeyProperties.PURPOSE_SIGN)
                    .setDigests(KeyProperties.DIGEST_SHA256)
                    .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
                    .setKeySize(2048)
                    .setCertificateSubject(X500Principal("CN=Tema RCM, O=Roma Club Matera"))
                    .setCertificateNotBefore(Date())
                    .setCertificateNotAfter(Date(System.currentTimeMillis() + 30L * 365 * 86_400_000))
                    .build()
            )
            g.generateKeyPair()
        }
        return (ks.getKey(CHIAVE, null) as PrivateKey) to (ks.getCertificate(CHIAVE) as X509Certificate)
    }

    /** Fa partire l'installazione; Android chiede conferma (EsitoInstallazione). */
    fun installa(c: Context, apk: File) {
        val pi = c.packageManager.packageInstaller
        val p = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply { setAppPackageName(NOME) }
        val id = pi.createSession(p)
        pi.openSession(id).use { s ->
            s.openWrite("pacchetto.apk", 0, apk.length()).use { out ->
                apk.inputStream().use { it.copyTo(out) }
                s.fsync(out)
            }
            val i = Intent(c, EsitoInstallazione::class.java).setPackage(c.packageName)
            val pe = PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
            s.commit(pe.intentSender)
        }
    }

    fun installato(c: Context): Long? = try {
        c.packageManager.getPackageInfo(NOME, 0).lastUpdateTime
    } catch (e: Exception) { null }
}

/** Android risponde qui: prima "serve la conferma", poi l'esito. */
class EsitoInstallazione : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        when (i.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val conferma = if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                else @Suppress("DEPRECATION") i.getParcelableExtra(Intent.EXTRA_INTENT)
                conferma?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)?.let { c.startActivity(it) }
            }
            PackageInstaller.STATUS_SUCCESS -> Pacchetto.esito?.invoke(true, null)
            else -> Pacchetto.esito?.invoke(false, i.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE))
        }
    }
}

/**
 * XML binario di Android (quello che aapt2 mette in res/xml), quanto basta per
 * <resources> con dentro <item> o simili, attributi stringa senza namespace.
 */
object Axml {
    fun risorse(elementi: List<List<Pair<String, String>>>, tag: String = "item"): ByteArray {
        val stringhe = LinkedHashMap<String, Int>()
        fun s(x: String) = stringhe.getOrPut(x) { stringhe.size }
        s("resources"); s(tag)
        elementi.forEach { e -> e.forEach { (k, v) -> s(k); s(v) } }
        val corpo = ByteArrayOutputStream()
        fun inizio(nome: String, attr: List<Pair<String, String>>) {
            val b = le(36 + 20 * attr.size)
            b.putShort(0x0102).putShort(16).putInt(36 + 20 * attr.size).putInt(1).putInt(-1)
            b.putInt(-1).putInt(s(nome)).putShort(20).putShort(20).putShort(attr.size.toShort()).putShort(0).putShort(0).putShort(0)
            attr.forEach { (k, v) -> b.putInt(-1).putInt(s(k)).putInt(s(v)).putShort(8).put(0).put(3).putInt(s(v)) }
            corpo.write(b.array())
        }
        fun fine(nome: String) {
            corpo.write(le(24).putShort(0x0103).putShort(16).putInt(24).putInt(1).putInt(-1).putInt(-1).putInt(s(nome)).array())
        }
        inizio("resources", emptyList())
        elementi.forEach { inizio(tag, it); fine(tag) }
        fine("resources")
        val pool = pool(stringhe.keys.toList())
        val tot = 8 + pool.size + corpo.size()
        return le(8).putShort(0x0003).putShort(8).putInt(tot).array() + pool + corpo.toByteArray()
    }

    private fun le(n: Int) = ByteBuffer.allocate(n).order(ByteOrder.LITTLE_ENDIAN)

    /** String pool UTF-8. */
    private fun pool(lista: List<String>): ByteArray {
        val dati = ByteArrayOutputStream()
        val offset = ArrayList<Int>()
        fun lunghezza(n: Int) = if (n > 0x7f) byteArrayOf(((n shr 8) or 0x80).toByte(), (n and 0xff).toByte()) else byteArrayOf(n.toByte())
        lista.forEach { x ->
            offset += dati.size()
            val b = x.toByteArray(Charsets.UTF_8)
            dati.write(lunghezza(x.length)); dati.write(lunghezza(b.size)); dati.write(b); dati.write(0)
        }
        while (dati.size() % 4 != 0) dati.write(0)
        val inizio = 28 + 4 * lista.size
        val tot = inizio + dati.size()
        val b = le(inizio).putShort(0x0001).putShort(28).putInt(tot).putInt(lista.size).putInt(0).putInt(0x100).putInt(inizio).putInt(0)
        offset.forEach { b.putInt(it) }
        return b.array() + dati.toByteArray()
    }
}
