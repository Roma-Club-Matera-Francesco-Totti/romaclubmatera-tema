package it.romaclubmatera.tema

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * I pallini della Home RCM: sa solo QUALI app hanno notifiche da leggere.
 * Il contenuto delle notifiche non si legge e non si salva. Funziona solo se
 * l'utente concede "Accesso alle notifiche" a Tema RCM.
 */
class Notifiche : NotificationListenerService() {

    companion object {
        @Volatile var ultime: Set<String> = emptySet()
        var ascolta: ((Set<String>) -> Unit)? = null

        fun permesso(c: Context): Boolean {
            val s = Settings.Secure.getString(c.contentResolver, "enabled_notification_listeners") ?: return false
            val mio = ComponentName(c, Notifiche::class.java).flattenToString()
            return s.split(':').any { it == mio }
        }
    }

    private fun aggiorna() {
        ultime = try {
            activeNotifications.orEmpty()
                .filter { it.isClearable && !it.isOngoing && it.packageName != packageName }
                .map { it.packageName }.toSet()
        } catch (e: Exception) { emptySet() }
        ascolta?.invoke(ultime)
    }

    override fun onListenerConnected() = aggiorna()
    override fun onNotificationPosted(sbn: StatusBarNotification?) = aggiorna()
    override fun onNotificationRemoved(sbn: StatusBarNotification?) = aggiorna()

    override fun onListenerDisconnected() {
        ultime = emptySet()
        ascolta?.invoke(ultime)
    }
}
