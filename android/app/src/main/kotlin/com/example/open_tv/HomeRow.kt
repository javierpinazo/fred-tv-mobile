package dev.fredol.open_tv

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import androidx.core.content.ContextCompat
import androidx.tvprovider.media.tv.PreviewChannel
import androidx.tvprovider.media.tv.PreviewChannelHelper
import androidx.tvprovider.media.tv.PreviewProgram
import androidx.tvprovider.media.tv.TvContractCompat

/**
 * Fila "Favoritos" de la pantalla de inicio de Android TV (canal de vista
 * previa). Cada elemento abre su canal con un enlace `fredtv://play?...`.
 * El nombre sale de los recursos (`strings.xml`) en el idioma del sistema.
 */
object HomeRow {
    private const val PREFS = "tv_home_row"
    private const val KEY_CHANNEL_ID = "channel_id"

    fun publish(context: Context, items: List<Map<String, String?>>) {
        val helper = PreviewChannelHelper(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        val channel = PreviewChannel.Builder()
            .setDisplayName(context.getString(R.string.home_row_name))
            .setDescription(context.getString(R.string.home_row_description))
            .setAppLinkIntentUri(Uri.parse("fredtv://home"))
            .setLogo(appIcon(context))
            .build()
        var channelId = prefs.getLong(KEY_CHANNEL_ID, -1L)
        if (channelId == -1L) {
            channelId = helper.publishDefaultChannel(channel)
            prefs.edit().putLong(KEY_CHANNEL_ID, channelId).apply()
        } else {
            // Si el idioma del sistema cambió, el nombre de la fila se actualiza.
            helper.updatePreviewChannel(channelId, channel)
        }

        // Se reemplaza el contenido anterior por el actual.
        context.contentResolver.delete(
            TvContractCompat.buildPreviewProgramsUriForChannel(channelId), null, null
        )
        for (item in items) {
            val title = item["title"] ?: continue
            val link = item["link"] ?: continue
            val builder = PreviewProgram.Builder()
                .setChannelId(channelId)
                .setType(TvContractCompat.PreviewPrograms.TYPE_CLIP)
                .setTitle(title)
                .setIntentUri(Uri.parse(link))
                .setPosterArtAspectRatio(TvContractCompat.PreviewPrograms.ASPECT_RATIO_16_9)
            item["image"]?.let { builder.setPosterArtUri(Uri.parse(it)) }
            helper.publishPreviewProgram(builder.build())
        }
    }

    /** El icono de la app (adaptativo) dibujado como imagen para el logo del canal. */
    private fun appIcon(context: Context): Bitmap {
        val size = 256
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val drawable = ContextCompat.getDrawable(context, R.mipmap.ic_launcher)
        if (drawable != null) {
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
        }
        return bitmap
    }
}
