package com.example.aurora

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * هوم‌ویجت Aurora: «ادامه تماشا» + تعداد پخش امروز.
 *
 * دیتا از سمت فلاتر (home_widget_service.dart) با کلیدهای زیر ذخیره می‌شود:
 * - cw_title: عنوان فرنچایز در حال تماشا
 * - cw_sub: زیرعنوان (قسمت بعدی)
 * - airing_today: تعداد آیتم‌های پخش امروز (int)
 *
 * تپ روی ویجت، اپ را باز می‌کند.
 */
class AuroraWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val title = widgetData.getString("cw_title", "ادامه تماشا")
                ?: "ادامه تماشا"
            val sub = widgetData.getString("cw_sub", "") ?: ""
            val todayCount = widgetData.getInt("airing_today", 0)
            val airingText =
                if (todayCount > 0) "امروز $todayCount پخش جدید" else ""

            val views = RemoteViews(
                context.packageName,
                R.layout.aurora_widget_layout
            ).apply {
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_sub, sub)
                setTextViewText(R.id.widget_airing, airingText)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
