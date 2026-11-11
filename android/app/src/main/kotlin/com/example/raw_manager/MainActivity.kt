package com.example.raw_manager

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.raw_manager/saf"
    private val REQUEST_CODE_OPEN_DIRECTORY = 4221
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDocumentTree" -> {
                    if (pendingResult != null) {
                        result.error("ALREADY_ACTIVE", "Un selettore è già in corso", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                        )
                    }
                    startActivityForResult(intent, REQUEST_CODE_OPEN_DIRECTORY)
                }

                "listRawFiles" -> {
                    val treeUriStr = call.argument<String>("treeUri")
                    if (treeUriStr == null) {
                        result.error("INVALID_ARGUMENT", "treeUri non fornito", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val treeUri = Uri.parse(treeUriStr)
                            val filesList = ArrayList<Map<String, Any>>()
                            scanDirectoryRecursively(treeUri, filesList)
                            runOnUiThread {
                                result.success(filesList)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("SCAN_ERROR", "Errore scansione SAF: ${e.message}", null)
                            }
                        }
                    }.start()
                }

                "extractRawBytes" -> {
                    val fileUriStr = call.argument<String>("uri")
                    if (fileUriStr == null) {
                        result.error("INVALID_ARGUMENT", "uri non fornito", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val fileUri = Uri.parse(fileUriStr)
                            val extracted = extractJpegFromUri(fileUri)
                            runOnUiThread {
                                if (extracted != null) {
                                    result.success(extracted)
                                } else {
                                    result.error("EXTRACTION_FAILED", "Impossibile estrarre anteprima JPEG da questo file RAW", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("EXTRACTION_ERROR", "Errore durante estrazione: ${e.message}", null)
                            }
                        }
                    }.start()
                }

                "copyRawFile" -> {
                    val sourceUriStr = call.argument<String>("sourceUri")
                    val targetTreeUriStr = call.argument<String>("targetTreeUri")
                    val fileName = call.argument<String>("fileName")

                    if (sourceUriStr == null || targetTreeUriStr == null || fileName == null) {
                        result.error("INVALID_ARGUMENT", "Parametri mancanti per copia", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val success = copyDocument(Uri.parse(sourceUriStr), Uri.parse(targetTreeUriStr), fileName)
                            runOnUiThread {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("COPY_ERROR", "Errore copia SAF: ${e.message}", null)
                            }
                        }
                    }.start()
                }

                "deleteRawFile" -> {
                    val fileUriStr = call.argument<String>("uri")
                    if (fileUriStr == null) {
                        result.error("INVALID_ARGUMENT", "uri non fornito", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val docUri = Uri.parse(fileUriStr)
                            val deleted = DocumentsContract.deleteDocument(contentResolver, docUri)
                            runOnUiThread {
                                result.success(deleted)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("DELETE_ERROR", "Errore eliminazione SAF: ${e.message}", null)
                            }
                        }
                    }.start()
                }

                "getAppInfo" -> {
                    try {
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        val info = HashMap<String, String>()
                        info["version"] = pInfo.versionName ?: "1.0.0"
                        info["cacheDir"] = cacheDir.absolutePath
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("INFO_ERROR", e.message, null)
                    }
                }

                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath mancante", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val apkFile = File(filePath)
                        if (!apkFile.exists()) {
                            result.error("FILE_NOT_FOUND", "APK non trovato: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            apkFile
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(installIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", "Errore avvio installer APK: ${e.message}", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_OPEN_DIRECTORY) {
            val res = pendingResult
            pendingResult = null

            if (resultCode == Activity.RESULT_OK && data != null && data.data != null) {
                val uri = data.data!!
                try {
                    val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    contentResolver.takePersistableUriPermission(uri, takeFlags)
                } catch (e: Exception) {
                    // Ignora se non persistable
                }
                res?.success(uri.toString())
            } else {
                res?.success(null)
            }
        }
    }

    private fun scanDirectoryRecursively(treeUri: Uri, results: ArrayList<Map<String, Any>>) {
        val rootDocId = DocumentsContract.getTreeDocumentId(treeUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, rootDocId)
        traverseChildren(treeUri, childrenUri, results, 0)
    }

    private val supportedExts = setOf("raf", "dng", "arw", "nef", "cr2", "cr3", "rw2", "orf", "pef")

    private fun traverseChildren(treeUri: Uri, childrenUri: Uri, results: ArrayList<Map<String, Any>>, depth: Int) {
        if (depth > 8) return

        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE
        )

        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)

            while (cursor.moveToNext()) {
                val docId = cursor.getString(idIndex)
                val displayName = cursor.getString(nameIndex) ?: ""
                val mimeType = cursor.getString(mimeIndex) ?: ""
                val size = cursor.getLong(sizeIndex)

                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                    val subChildrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
                    traverseChildren(treeUri, subChildrenUri, results, depth + 1)
                } else {
                    val ext = displayName.substringAfterLast('.', "").lowercase()
                    if (supportedExts.contains(ext)) {
                        val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                        val item = HashMap<String, Any>()
                        item["uri"] = docUri.toString()
                        item["displayName"] = displayName
                        item["size"] = size
                        results.add(item)
                    }
                }
            }
        }
    }

    /**
     * Legge finché il buffer non è pieno. Su schede SD/USB OTG via SAF una singola
     * FileChannel.read() può restituire solo una parte dei byte richiesti: il JPEG
     * risultava troncato (schermo nero + "EXIF N/D").
     */
    private fun java.nio.channels.FileChannel.readFully(buf: ByteBuffer): Int {
        var total = 0
        while (buf.hasRemaining()) {
            val n = this.read(buf)
            if (n <= 0) break
            total += n
        }
        return total
    }

    private fun extractJpegFromUri(uri: Uri): ByteArray? {
        val pfd = contentResolver.openFileDescriptor(uri, "r") ?: return null
        return pfd.use { parcelFd ->
            val fileChannel = java.io.FileInputStream(parcelFd.fileDescriptor).channel
            val fileSize = fileChannel.size()
            if (fileSize < 92) return null

            // 1. Estrazione ad accesso casuale per Fujifilm .RAF (< 5ms)
            val headerBuffer = ByteBuffer.allocate(92)
            fileChannel.position(0)
            fileChannel.readFully(headerBuffer)
            headerBuffer.flip()

            val magicBytes = ByteArray(16)
            headerBuffer.get(magicBytes)
            val magicStr = String(magicBytes, Charsets.US_ASCII)

            if (magicStr == "FUJIFILMCCD-RAW ") {
                headerBuffer.position(0x54)
                headerBuffer.order(ByteOrder.BIG_ENDIAN)
                val jpegOffset = headerBuffer.getInt().toLong() and 0xFFFFFFFFL
                val jpegLength = headerBuffer.getInt()

                if (jpegOffset in 92 until fileSize && jpegLength > 50 && (jpegOffset + jpegLength) <= fileSize) {
                    val jpegBuffer = ByteBuffer.allocate(jpegLength)
                    fileChannel.position(jpegOffset)
                    fileChannel.readFully(jpegBuffer)
                    val bytes = jpegBuffer.array()
                    if (bytes.size >= 4 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xD8.toByte()) {
                        return bytes
                    }
                }
            }

            // 2. Estrazione diretta IFD/TIFF per DNG, ARW, NEF, CR2 (< 10ms)
            val tiffBytes = extractTiffJpeg(fileChannel, fileSize)
            if (tiffBytes != null) {
                return tiffBytes
            }

            // 3. Fallback di scansione per altri formati RAW nei primi blocchi
            val scanLimit = minOf(fileSize, 25L * 1024 * 1024).toInt()
            val scanBuffer = ByteBuffer.allocate(scanLimit)
            fileChannel.position(0)
            fileChannel.readFully(scanBuffer)
            val rawBytes = scanBuffer.array()

            var bestStart = -1
            var bestLength = 0

            for (i in 0 until scanLimit - 1) {
                if (rawBytes[i] == 0xFF.toByte() && rawBytes[i + 1] == 0xD8.toByte()) {
                    for (j in i + 50 until scanLimit - 1) {
                        if (rawBytes[j] == 0xFF.toByte() && rawBytes[j + 1] == 0xD9.toByte()) {
                            val len = j - i + 2
                            if (len > bestLength && len > 50) {
                                bestStart = i
                                bestLength = len
                            }
                            break
                        }
                    }
                }
            }

            if (bestStart >= 0 && bestLength > 0) {
                val resultBytes = ByteArray(bestLength)
                System.arraycopy(rawBytes, bestStart, resultBytes, 0, bestLength)
                return resultBytes
            }

            null
        }
    }

    private fun extractTiffJpeg(channel: java.nio.channels.FileChannel, fileSize: Long): ByteArray? {
        try {
            val tiffHeader = ByteBuffer.allocate(8)
            channel.position(0)
            channel.readFully(tiffHeader)
            tiffHeader.flip()

            val b0 = tiffHeader.get().toInt().toChar()
            val b1 = tiffHeader.get().toInt().toChar()
            val endian = when {
                b0 == 'I' && b1 == 'I' -> ByteOrder.LITTLE_ENDIAN
                b0 == 'M' && b1 == 'M' -> ByteOrder.BIG_ENDIAN
                else -> return null
            }

            tiffHeader.order(endian)
            val magic = tiffHeader.short.toInt() and 0xFFFF
            if (magic != 42 && magic != 0x4F52) return null

            val ifdOffset = tiffHeader.int.toLong() and 0xFFFFFFFFL
            return findTiffPreview(channel, ifdOffset, endian, fileSize, 0)
        } catch (e: Exception) {
            return null
        }
    }

    private fun findTiffPreview(
        channel: java.nio.channels.FileChannel,
        ifdOffset: Long,
        endian: ByteOrder,
        fileSize: Long,
        depth: Int
    ): ByteArray? {
        if (depth > 4 || ifdOffset <= 0 || ifdOffset >= fileSize - 6) return null

        try {
            val countBuf = ByteBuffer.allocate(2).order(endian)
            channel.position(ifdOffset)
            channel.readFully(countBuf)
            countBuf.flip()

            val numEntries = countBuf.short.toInt() and 0xFFFF
            if (numEntries <= 0 || numEntries > 500) return null

            val entriesBuf = ByteBuffer.allocate(numEntries * 12).order(endian)
            channel.position(ifdOffset + 2)
            channel.readFully(entriesBuf)
            entriesBuf.flip()

            var jpegOffset: Long = -1
            var jpegLength: Int = -1
            val subIfds = ArrayList<Long>()

            for (i in 0 until numEntries) {
                val tag = entriesBuf.getShort().toInt() and 0xFFFF
                val type = entriesBuf.getShort().toInt() and 0xFFFF
                val count = entriesBuf.getInt().toLong() and 0xFFFFFFFFL
                val valOffset = entriesBuf.getInt().toLong() and 0xFFFFFFFFL

                when (tag) {
                    0x0201 -> jpegOffset = valOffset
                    0x0202 -> jpegLength = valOffset.toInt()
                    0x014A -> {
                        if (count == 1L) {
                            subIfds.add(valOffset)
                        } else if (count in 2L..10L) {
                            val subBuf = ByteBuffer.allocate((count * 4).toInt()).order(endian)
                            channel.position(valOffset)
                            channel.readFully(subBuf)
                            subBuf.flip()
                            for (j in 0 until count.toInt()) {
                                subIfds.add(subBuf.getInt().toLong() and 0xFFFFFFFFL)
                            }
                        }
                    }
                }
            }

            var bestBytes: ByteArray? = null
            if (jpegOffset in 8 until fileSize && jpegLength > 50 && (jpegOffset + jpegLength) <= fileSize) {
                val buf = ByteBuffer.allocate(jpegLength)
                channel.position(jpegOffset)
                channel.readFully(buf)
                val bytes = buf.array()
                if (bytes.size >= 4 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xD8.toByte()) {
                    bestBytes = bytes
                }
            }

            for (sub in subIfds) {
                val subResult = findTiffPreview(channel, sub, endian, fileSize, depth + 1)
                if (subResult != null && (bestBytes == null || subResult.size > bestBytes.size)) {
                    bestBytes = subResult
                }
            }

            return bestBytes
        } catch (e: Exception) {
            return null
        }
    }

    private fun copyDocument(sourceUri: Uri, targetTreeUri: Uri, fileName: String): Boolean {
        val targetRootDocId = DocumentsContract.getTreeDocumentId(targetTreeUri)
        val targetDocUri = DocumentsContract.buildDocumentUriUsingTree(targetTreeUri, targetRootDocId)
        val createdFileUri = DocumentsContract.createDocument(
            contentResolver,
            targetDocUri,
            "application/octet-stream",
            fileName
        ) ?: return false

        contentResolver.openInputStream(sourceUri)?.use { input ->
            contentResolver.openOutputStream(createdFileUri)?.use { output ->
                input.copyTo(output)
            }
        } ?: return false

        return true
    }
}
