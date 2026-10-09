package it.romaclubmatera.tema

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.Drawable

/**
 * Come personale/cornice.py: tondo rosso sfumato, l'icona originale
 * ritagliata a cerchio, filetto oro. Le icone adattive si disegnano a
 * strati, senza la forma del telefono: niente quadrati bianchi attorno.
 * La usano la Home RCM e il pacchetto per Theme Park (Pacchetto.kt).
 */
object Cornice {
    fun disegna(tela: Canvas, l: Float, orig: Drawable) {
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
}
