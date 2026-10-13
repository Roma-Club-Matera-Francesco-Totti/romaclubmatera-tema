package it.romaclubmatera.tema

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.provider.AlarmClock
import android.widget.RemoteViews

/**
 * Widget "Orologio giallorosso": ora e data le aggiorna il sistema
 * (TextClock), qui si collega solo il tocco, che apre la sveglia.
 */
class WidgetOrologio : AppWidgetProvider() {

    override fun onUpdate(ctx: Context, am: AppWidgetManager, ids: IntArray) {
        val v = RemoteViews(ctx.packageName, R.layout.widget_orologio)
        val sveglia = Intent(AlarmClock.ACTION_SHOW_ALARMS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (sveglia.resolveActivity(ctx.packageManager) != null) {
            v.setOnClickPendingIntent(R.id.radice, PendingIntent.getActivity(ctx, 2, sveglia,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }
        for (id in ids) am.updateAppWidget(id, v)
    }
}
