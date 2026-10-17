package com.khaled.shelves

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.util.Base64
import android.util.Log
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Everything the launcher needs from Android, and nothing else. Godot owns all
 * UI, 3D and data; when a new Android capability is needed it gets a method
 * here rather than a workaround in GDScript.
 *
 * All calls return JSON strings, which keeps the Godot<->JNI surface to plain
 * strings and makes adding fields later a non-event.
 */
class LauncherPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "LauncherPlugin"
        private const val ICON_SIZE = 128
        const val SIGNAL_APPS_CHANGED = "apps_changed"
    }

    private var packageReceiver: BroadcastReceiver? = null

    override fun getPluginName(): String = "LauncherPlugin"

    override fun getPluginSignals(): Set<SignalInfo> =
        setOf(SignalInfo(SIGNAL_APPS_CHANGED, String::class.java))

    override fun onGodotMainLoopStarted() {
        registerPackageReceiver()
    }

    override fun onMainDestroy() {
        packageReceiver?.let {
            runCatching { activity?.unregisterReceiver(it) }
            packageReceiver = null
        }
        super.onMainDestroy()
    }

    // ------------------------------------------------------------------ apps

    /** JSON array of `{package, name, activity}` for every launchable app. */
    @UsedByGodot
    fun getInstalledApps(): String {
        val context = activity ?: return "[]"
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val result = JSONArray()
        try {
            for (info in pm.queryIntentActivities(intent, 0)) {
                val app = info.activityInfo ?: continue
                if (app.packageName == context.packageName) continue
                result.put(
                    JSONObject()
                        .put("package", app.packageName)
                        .put("name", info.loadLabel(pm).toString())
                        .put("activity", app.name)
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "getInstalledApps failed", e)
        }
        return result.toString()
    }

    /** Base64 PNG of the app icon, or an empty string. */
    @UsedByGodot
    fun getAppIcon(packageName: String): String {
        val context = activity ?: return ""
        return try {
            val drawable: Drawable = context.packageManager.getApplicationIcon(packageName)
            val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
            drawable.draw(canvas)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.w(TAG, "no icon for $packageName: ${e.message}")
            ""
        }
    }

    @UsedByGodot
    fun launchApp(packageName: String): Boolean {
        val context = activity ?: return false
        return try {
            val intent = context.packageManager.getLaunchIntentForPackage(packageName)
                ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "launchApp($packageName) failed", e)
            false
        }
    }

    /**
     * A custom launch action, as JSON. Three shapes:
     *   {"type":"uri","data":"gamenative://play/123"}
     *   {"type":"component","package":"com.x","component":"com.x.MainActivity"}
     *   {"type":"package","package":"com.x"}
     * Optional: "action" (defaults to VIEW for a uri, MAIN otherwise) and
     * "extras", a flat object of string values.
     */
    @UsedByGodot
    fun launchIntent(json: String): Boolean {
        val context = activity ?: return false
        return try {
            val spec = JSONObject(json)
            val type = spec.optString("type", "uri")
            val intent = when (type) {
                "uri" -> Intent(
                    spec.optString("action", Intent.ACTION_VIEW),
                    android.net.Uri.parse(spec.getString("data"))
                )
                "component" -> Intent(spec.optString("action", Intent.ACTION_MAIN)).apply {
                    setClassName(spec.getString("package"), spec.getString("component"))
                }
                else -> context.packageManager
                    .getLaunchIntentForPackage(spec.getString("package"))
                    ?: return false
            }
            spec.optJSONObject("extras")?.let { extras ->
                for (key in extras.keys()) intent.putExtra(key, extras.getString(key))
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "launchIntent failed: $json", e)
            false
        }
    }

    // ---------------------------------------------------------------- status

    /** `{level: 0-100, charging: bool}` */
    @UsedByGodot
    fun getBatteryState(): String {
        val context = activity ?: return """{"level":100,"charging":false}"""
        return try {
            val sticky = context.registerReceiver(
                null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            val level = sticky?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = sticky?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
            val status = sticky?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val percent = if (level >= 0 && scale > 0) level * 100 / scale else 100
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
            JSONObject().put("level", percent).put("charging", charging).toString()
        } catch (e: Exception) {
            Log.e(TAG, "getBatteryState failed", e)
            """{"level":100,"charging":false}"""
        }
    }

    /** `{connected: bool, type: "wifi"|"cellular"|"ethernet"|"none", level: 0-4}` */
    @UsedByGodot
    fun getNetworkState(): String {
        val context = activity ?: return """{"connected":false,"type":"none","level":0}"""
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork
            val caps = network?.let { cm.getNetworkCapabilities(it) }
            var type = "none"
            var level = 0
            var connected = false
            if (caps != null && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                connected = true
                when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> {
                        type = "wifi"
                        level = wifiLevel(context, caps)
                    }
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> {
                        type = "cellular"
                        level = 4
                    }
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> {
                        type = "ethernet"
                        level = 4
                    }
                }
            }
            JSONObject()
                .put("connected", connected)
                .put("type", type)
                .put("level", level)
                .toString()
        } catch (e: Exception) {
            Log.e(TAG, "getNetworkState failed", e)
            """{"connected":false,"type":"none","level":0}"""
        }
    }

    @Suppress("DEPRECATION")
    private fun wifiLevel(context: Context, caps: NetworkCapabilities): Int {
        val wm = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return 4
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // signalStrength is the RSSI in dBm on API 29+
                val rssi = caps.signalStrength
                if (rssi == Int.MIN_VALUE) 4 else wm.calculateSignalLevel(rssi)
                    .coerceIn(0, 4)
            } else {
                WifiManager.calculateSignalLevel(wm.connectionInfo.rssi, 5).coerceIn(0, 4)
            }
        } catch (e: Exception) {
            4
        }
    }

    // ------------------------------------------------------- package changes

    private fun registerPackageReceiver() {
        val context = activity ?: return
        if (packageReceiver != null) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addDataScheme("package")
        }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val changed = intent?.data?.schemeSpecificPart ?: ""
                emitSignal(SIGNAL_APPS_CHANGED, changed)
            }
        }
        packageReceiver = receiver
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(receiver, filter)
            }
        } catch (e: Exception) {
            Log.e(TAG, "cannot watch package changes", e)
            packageReceiver = null
        }
    }
}
