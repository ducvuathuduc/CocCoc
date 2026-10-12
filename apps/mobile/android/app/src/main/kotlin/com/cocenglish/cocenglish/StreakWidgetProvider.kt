package com.cocenglish.cocenglish

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen streak widget. Flutter writes the values through `home_widget`
 * (keys from `StreakHomeWidgetData.toStorage()`), then asks for an update
 * after every lesson and on app start. Tapping opens the learning path.
 */
class StreakWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val streak = widgetData.number("coc_streak")
        val flame = widgetData.getString("coc_flame", "none") ?: "none"
        val goal = widgetData.number("coc_goal_minutes").coerceAtLeast(1)
        val today = widgetData.number("coc_today_minutes")
        val percent = widgetData.number("coc_goal_percent").coerceIn(0, 100)
        val headline = widgetData.getString("coc_headline", null)
            ?: context.getString(R.string.streak_widget_default)
        val link = widgetData.getString("coc_link", "/home") ?: "/home"

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                setImageViewResource(
                    R.id.streak_widget_flame,
                    when (flame) {
                        "lit" -> R.drawable.ic_widget_flame_lit
                        "atRisk" -> R.drawable.ic_widget_flame_risk
                        else -> R.drawable.ic_widget_flame_none
                    },
                )
                setTextViewText(R.id.streak_widget_count, streak.toString())
                setTextColor(
                    R.id.streak_widget_count,
                    context.getColor(if (flame == "lit") R.color.coc_flame else R.color.coc_flame_off),
                )
                setTextViewText(R.id.streak_widget_headline, headline)
                setProgressBar(R.id.streak_widget_goal, 100, percent, false)
                setTextViewText(
                    R.id.streak_widget_goal_label,
                    context.getString(R.string.streak_widget_goal, today.coerceAtMost(goal), goal),
                )
                setOnClickPendingIntent(
                    R.id.streak_widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("cocenglish://widget$link"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun SharedPreferences.number(key: String): Int =
        (all[key] as? Number)?.toInt() ?: 0
}
