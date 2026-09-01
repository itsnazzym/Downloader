package com.downloader.modern_downloader

import android.content.Context
import android.os.Environment
import java.io.File

object AndroidStorage {
    fun defaultOutputFolder(context: Context): String {
        val publicDownloads =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val publicDest = File(publicDownloads, "ModernDownloader")
        return try {
            if (!publicDest.exists()) {
                publicDest.mkdirs()
            }
            if (publicDest.exists() && publicDest.canWrite()) {
                publicDest.absolutePath
            } else {
                fallbackFolder(context)
            }
        } catch (_: Exception) {
            fallbackFolder(context)
        }
    }

    private fun fallbackFolder(context: Context): String {
        val base =
            context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: context.filesDir
        val dest = File(base, "ModernDownloader")
        dest.mkdirs()
        return dest.absolutePath
    }
}
