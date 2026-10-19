package dev.fredol.open_tv

import android.app.SearchManager
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var tvChannel: MethodChannel? = null
    private var initialLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialLink = linkFrom(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "dev.fredol.open_tv/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "isTv") {
                    result.success(isTv())
                } else {
                    result.notImplemented()
                }
            }

        // Enlaces entrantes (pantalla de inicio, búsqueda) y fila de favoritos.
        tvChannel = MethodChannel(messenger, "dev.fredol.open_tv/tv").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialLink" -> {
                        result.success(initialLink)
                        initialLink = null
                    }
                    "publishFavorites" -> {
                        val items = (call.arguments as? List<*>)?.mapNotNull { raw ->
                            (raw as? Map<*, *>)?.entries?.associate {
                                it.key.toString() to it.value?.toString()
                            }
                        } ?: emptyList()
                        // Fuera del hilo principal: toca el proveedor de contenido de la TV.
                        Thread {
                            try {
                                HomeRow.publish(applicationContext, items)
                            } catch (e: Exception) {
                                Log.w("HomeRow", "No se pudo publicar la fila de inicio", e)
                            }
                        }.start()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        linkFrom(intent)?.let { tvChannel?.invokeMethod("link", it) }
    }

    /** Convierte el intent recibido en un enlace `fredtv://…` o `null`. */
    private fun linkFrom(intent: Intent?): String? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_VIEW ->
                intent.dataString?.takeIf { it.startsWith("fredtv://") }
            Intent.ACTION_SEARCH, "com.google.android.gms.actions.SEARCH_ACTION" -> {
                val query = intent.getStringExtra(SearchManager.QUERY)?.trim()
                if (query.isNullOrEmpty()) null
                else Uri.Builder().scheme("fredtv").authority("search")
                    .appendQueryParameter("q", query).build().toString()
            }
            else -> null
        }
    }

    private fun isTv(): Boolean {
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }
}
