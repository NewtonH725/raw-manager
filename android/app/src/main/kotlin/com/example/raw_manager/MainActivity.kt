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

                "extractExifSummary" -> {
                    val fileUriStr = call.argument<String>("uri")
                    if (fileUriStr == null) {
                        result.error("INVALID_ARGUMENT", "uri non fornito", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val summary = extractExifSummaryFromUri(Uri.parse(fileUriStr))
                        runOnUiThread {
                            result.success(summary)
                        }
                    }.start()
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

            // 2. Estrazione diretta IFD/TIFF per DNG (Ricoh GR IIIx, Adobe), ARW, NEF, CR2 (< 10ms)
            val tiffBytes = extractTiffJpeg(fileChannel, fileSize)
            if (tiffBytes != null) {
                return tiffBytes
            }

            // 3. Fallback avanzato di scansione (esclude Lossless SOF3 e gestisce APP1 EXIF annidati)
            return scanForEmbeddedJpeg(fileChannel, fileSize)
        }
    }

    private data class JpegHeaderInfo(val isDecodable: Boolean, val width: Int, val height: Int)
    private data class JpegCandidate(val offset: Long, val length: Int, val width: Int, val height: Int) {
        val pixelArea: Long get() = width.toLong() * height.toLong()
        fun isBetterThan(other: JpegCandidate?): Boolean {
            if (other == null) return true
            if (pixelArea > 0 && other.pixelArea > 0 && pixelArea != other.pixelArea) {
                return pixelArea > other.pixelArea
            }
            return length > other.length
        }
    }

    private fun inspectJpegHeader(bytes: ByteArray, length: Int = bytes.size): JpegHeaderInfo {
        if (length < 10 || bytes[0] != 0xFF.toByte() || bytes[1] != 0xD8.toByte() || bytes[2] != 0xFF.toByte()) {
            return JpegHeaderInfo(false, 0, 0)
        }
        var pos = 2
        while (pos + 3 < length) {
            if (bytes[pos] != 0xFF.toByte()) {
                pos++
                continue
            }
            while (pos < length && bytes[pos] == 0xFF.toByte()) {
                pos++
            }
            if (pos >= length) break
            val marker = bytes[pos].toInt() and 0xFF
            pos++

            if (marker == 0x00 || marker == 0x01 || (marker in 0xD0..0xD9)) {
                if (marker == 0xD9) break
                continue
            }
            if (pos + 1 >= length) break
            val segLen = ((bytes[pos].toInt() and 0xFF) shl 8) or (bytes[pos + 1].toInt() and 0xFF)
            if (segLen < 2) break

            if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
                var w = 0
                var h = 0
                if (pos + 7 < length) {
                    val precision = bytes[pos + 2].toInt() and 0xFF
                    h = ((bytes[pos + 3].toInt() and 0xFF) shl 8) or (bytes[pos + 4].toInt() and 0xFF)
                    w = ((bytes[pos + 5].toInt() and 0xFF) shl 8) or (bytes[pos + 6].toInt() and 0xFF)
                    val components = bytes[pos + 7].toInt() and 0xFF
                    if (precision != 8 || w <= 0 || h <= 0 || (components != 1 && components != 3)) {
                        return JpegHeaderInfo(false, 0, 0)
                    }
                }
                return JpegHeaderInfo(true, w, h)
            }

            if (marker == 0xC3 || marker == 0xC5 || marker == 0xC6 || marker == 0xC7 ||
                marker == 0xC9 || marker == 0xCA || marker == 0xCB ||
                marker == 0xCD || marker == 0xCE || marker == 0xCF) {
                return JpegHeaderInfo(false, 0, 0)
            }

            if (marker == 0xDA) break
            pos += segLen
        }
        return JpegHeaderInfo(false, 0, 0)
    }

    private fun trimAndValidateJpeg(bytes: ByteArray): ByteArray? {
        if (bytes.size < 4 || bytes[0] != 0xFF.toByte() || bytes[1] != 0xD8.toByte()) return null
        if (bytes[bytes.size - 2] == 0xFF.toByte() && bytes[bytes.size - 1] == 0xD9.toByte()) {
            return bytes
        }
        val searchStart = maxOf(2, bytes.size - 66)
        for (i in bytes.size - 2 downTo searchStart) {
            if (bytes[i] == 0xFF.toByte() && bytes[i + 1] == 0xD9.toByte()) {
                return bytes.copyOfRange(0, i + 2)
            }
        }
        return null
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
            val visitedIfds = HashSet<Long>()
            val best = findBestTiffPreview(channel, ifdOffset, endian, fileSize, visitedIfds, 0) ?: return null

            val buf = ByteBuffer.allocate(best.length)
            channel.position(best.offset)
            channel.readFully(buf)
            return trimAndValidateJpeg(buf.array())
        } catch (e: Exception) {
            return null
        }
    }

    private fun readTiffIntValues(
        channel: java.nio.channels.FileChannel,
        type: Int,
        count: Long,
        rawValOffsetBytes: ByteArray,
        endian: ByteOrder,
        fileSize: Long
    ): List<Long> {
        if (count <= 0L || count > 200L) return emptyList()
        val bb = ByteBuffer.wrap(rawValOffsetBytes).order(endian)

        if (count == 1L) {
            return if (type == 3) {
                listOf((bb.short.toInt() and 0xFFFF).toLong())
            } else {
                listOf(bb.int.toLong() and 0xFFFFFFFFL)
            }
        }
        if (count == 2L && type == 3) {
            val v1 = (bb.short.toInt() and 0xFFFF).toLong()
            val v2 = (bb.short.toInt() and 0xFFFF).toLong()
            return listOf(v1, v2)
        }

        val valOffset = bb.int.toLong() and 0xFFFFFFFFL
        val elemSize = if (type == 3) 2 else 4
        if (valOffset <= 0L || valOffset + count * elemSize > fileSize) return emptyList()

        return try {
            val dataBuf = ByteBuffer.allocate((count * elemSize).toInt()).order(endian)
            channel.position(valOffset)
            channel.readFully(dataBuf)
            dataBuf.flip()
            val out = ArrayList<Long>(count.toInt())
            for (i in 0 until count.toInt()) {
                if (type == 3) {
                    out.add((dataBuf.short.toInt() and 0xFFFF).toLong())
                } else {
                    out.add(dataBuf.int.toLong() and 0xFFFFFFFFL)
                }
            }
            out
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun validateTiffCandidate(
        channel: java.nio.channels.FileChannel,
        offset: Long,
        length: Int,
        fileSize: Long
    ): JpegCandidate? {
        if (offset < 8L || length <= 50 || offset + length > fileSize) return null
        return try {
            val probeLen = minOf(length, 65536)
            val probeBuf = ByteBuffer.allocate(probeLen)
            channel.position(offset)
            channel.readFully(probeBuf)
            val probe = probeBuf.array()
            val header = inspectJpegHeader(probe, probeLen)
            if (!header.isDecodable) return null
            JpegCandidate(offset, length, header.width, header.height)
        } catch (e: Exception) {
            null
        }
    }

    private fun findBestTiffPreview(
        channel: java.nio.channels.FileChannel,
        ifdOffset: Long,
        endian: ByteOrder,
        fileSize: Long,
        visitedIfds: HashSet<Long>,
        depth: Int
    ): JpegCandidate? {
        if (depth > 8 || ifdOffset <= 0L || ifdOffset >= fileSize - 6) return null
        if (!visitedIfds.add(ifdOffset)) return null

        try {
            val countBuf = ByteBuffer.allocate(2).order(endian)
            channel.position(ifdOffset)
            channel.readFully(countBuf)
            countBuf.flip()

            val numEntries = countBuf.short.toInt() and 0xFFFF
            if (numEntries <= 0 || numEntries > 1000) return null

            val entriesBuf = ByteBuffer.allocate(numEntries * 12).order(endian)
            channel.position(ifdOffset + 2)
            channel.readFully(entriesBuf)
            entriesBuf.flip()

            val nextIfdPtrPos = ifdOffset + 2L + numEntries * 12L
            var nextIfdOffset = 0L
            if (nextIfdPtrPos + 4 <= fileSize) {
                val nextBuf = ByteBuffer.allocate(4).order(endian)
                channel.position(nextIfdPtrPos)
                channel.readFully(nextBuf)
                nextBuf.flip()
                nextIfdOffset = nextBuf.int.toLong() and 0xFFFFFFFFL
            }

            var jpegInterchangeOffset = -1L
            var jpegInterchangeLength = -1
            var stripOffsets: List<Long> = emptyList()
            var stripByteCounts: List<Long> = emptyList()
            var compression = 0
            var photometric = -1
            var bitsPerSample = 8
            var hasJpegTables = false
            val childIfds = ArrayList<Long>()

            for (i in 0 until numEntries) {
                val tag = entriesBuf.short.toInt() and 0xFFFF
                val type = entriesBuf.short.toInt() and 0xFFFF
                val count = entriesBuf.int.toLong() and 0xFFFFFFFFL
                val rawField = ByteArray(4)
                entriesBuf.get(rawField)
                val valOffset = ByteBuffer.wrap(rawField).order(endian).int.toLong() and 0xFFFFFFFFL

                when (tag) {
                    0x0102 -> {
                        val vals = readTiffIntValues(channel, type, count, rawField, endian, fileSize)
                        if (vals.isNotEmpty()) bitsPerSample = vals[0].toInt()
                    }
                    0x0103 -> {
                        val vals = readTiffIntValues(channel, type, count, rawField, endian, fileSize)
                        if (vals.isNotEmpty()) compression = vals[0].toInt()
                    }
                    0x0106 -> {
                        val vals = readTiffIntValues(channel, type, count, rawField, endian, fileSize)
                        if (vals.isNotEmpty()) photometric = vals[0].toInt()
                    }
                    0x0111 -> stripOffsets = readTiffIntValues(channel, type, count, rawField, endian, fileSize)
                    0x0117 -> stripByteCounts = readTiffIntValues(channel, type, count, rawField, endian, fileSize)
                    0x015B -> hasJpegTables = true
                    0x0201 -> jpegInterchangeOffset = valOffset
                    0x0202 -> jpegInterchangeLength = valOffset.toInt()
                    0x014A -> childIfds.addAll(readTiffIntValues(channel, type, count, rawField, endian, fileSize))
                    0x8769 -> if (valOffset in 1 until fileSize) childIfds.add(valOffset)
                }
            }

            var best: JpegCandidate? = null
            val isRawSensorData = bitsPerSample > 8 || photometric == 32803 || photometric == 34892

            if (!isRawSensorData && jpegInterchangeOffset > 0 && jpegInterchangeLength > 50) {
                val cand = validateTiffCandidate(channel, jpegInterchangeOffset, jpegInterchangeLength, fileSize)
                if (cand != null && cand.isBetterThan(best)) best = cand
            }

            if (!isRawSensorData && (compression == 6 || compression == 7 || compression == 0) &&
                stripOffsets.isNotEmpty() && stripByteCounts.isNotEmpty()) {
                if (stripOffsets.size == 1) {
                    val cand = validateTiffCandidate(channel, stripOffsets[0], stripByteCounts[0].toInt(), fileSize)
                    if (cand != null && cand.isBetterThan(best)) best = cand
                } else if (!hasJpegTables && stripOffsets.size == stripByteCounts.size) {
                    var contiguous = true
                    var totalLen = stripByteCounts[0]
                    for (s in 1 until stripOffsets.size) {
                        if (stripOffsets[s] != stripOffsets[s - 1] + stripByteCounts[s - 1]) {
                            contiguous = false
                            break
                        }
                        totalLen += stripByteCounts[s]
                    }
                    if (contiguous && totalLen <= Int.MAX_VALUE) {
                        val cand = validateTiffCandidate(channel, stripOffsets[0], totalLen.toInt(), fileSize)
                        if (cand != null && cand.isBetterThan(best)) best = cand
                    }
                }
            }

            for (child in childIfds) {
                val subCand = findBestTiffPreview(channel, child, endian, fileSize, visitedIfds, depth + 1)
                if (subCand != null && subCand.isBetterThan(best)) best = subCand
            }

            if (nextIfdOffset > 0) {
                val nextCand = findBestTiffPreview(channel, nextIfdOffset, endian, fileSize, visitedIfds, depth + 1)
                if (nextCand != null && nextCand.isBetterThan(best)) best = nextCand
            }

            return best
        } catch (e: Exception) {
            return null
        }
    }

    private fun scanForEmbeddedJpeg(channel: java.nio.channels.FileChannel, fileSize: Long): ByteArray? {
        val headLimit = minOf(fileSize, 25L * 1024 * 1024).toInt()
        val headBuf = ByteBuffer.allocate(headLimit)
        channel.position(0)
        channel.readFully(headBuf)
        var best = scanBufferForBestJpeg(headBuf.array())

        val tailLimit = 20L * 1024 * 1024
        if (fileSize > headLimit && (best == null || best.second * best.third < 320 * 240)) {
            val tailStart = maxOf(0L, fileSize - tailLimit)
            val tailSize = (fileSize - tailStart).toInt()
            val tailBuf = ByteBuffer.allocate(tailSize)
            channel.position(tailStart)
            channel.readFully(tailBuf)
            val tailBest = scanBufferForBestJpeg(tailBuf.array())
            if (tailBest != null && (best == null || tailBest.second * tailBest.third > best.second * best.third)) {
                best = tailBest
            }
        }
        return best?.first
    }

    private fun scanBufferForBestJpeg(buf: ByteArray): Triple<ByteArray, Int, Int>? {
        var bestStart = -1
        var bestEnd = -1
        var bestArea = -1
        var bestLen = 0
        var bestW = 0
        var bestH = 0

        var i = 0
        while (i < buf.size - 10) {
            if (buf[i] == 0xFF.toByte() && buf[i + 1] == 0xD8.toByte() && buf[i + 2] == 0xFF.toByte()) {
                val parsed = measureJpegStream(buf, i)
                if (parsed != null) {
                    val (endOffset, w, h) = parsed
                    val len = endOffset - i
                    val area = w * h
                    if (len > 50 && ((area > 0 && area > bestArea) || (area == bestArea && len > bestLen))) {
                        bestStart = i
                        bestEnd = endOffset
                        bestArea = area
                        bestLen = len
                        bestW = w
                        bestH = h
                    }
                    i = endOffset
                    continue
                }
            }
            i++
        }

        return if (bestStart >= 0 && bestEnd > bestStart) {
            Triple(buf.copyOfRange(bestStart, bestEnd), bestW, bestH)
        } else null
    }

    private fun measureJpegStream(buf: ByteArray, startPos: Int): Triple<Int, Int, Int>? {
        var pos = startPos + 2
        val limit = buf.size
        var decodableSof = false
        var width = 0
        var height = 0
        var seenSos = false

        while (pos + 1 < limit) {
            if (!seenSos) {
                if (buf[pos] != 0xFF.toByte()) return null
                while (pos < limit && buf[pos] == 0xFF.toByte()) pos++
                if (pos >= limit) return null
                val marker = buf[pos].toInt() and 0xFF
                pos++

                if (marker == 0xD9) return if (decodableSof) Triple(pos, width, height) else null
                if (marker == 0x00 || marker == 0x01 || marker in 0xD0..0xD8) continue
                if (pos + 1 >= limit) return null
                val segLen = ((buf[pos].toInt() and 0xFF) shl 8) or (buf[pos + 1].toInt() and 0xFF)
                if (segLen < 2 || pos + segLen > limit) return null

                if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
                    decodableSof = true
                    if (pos + 7 < limit) {
                        val precision = buf[pos + 2].toInt() and 0xFF
                        height = ((buf[pos + 3].toInt() and 0xFF) shl 8) or (buf[pos + 4].toInt() and 0xFF)
                        width = ((buf[pos + 5].toInt() and 0xFF) shl 8) or (buf[pos + 6].toInt() and 0xFF)
                        val components = buf[pos + 7].toInt() and 0xFF
                        if (precision != 8 || width <= 0 || height <= 0 || (components != 1 && components != 3)) return null
                    }
                } else if (marker == 0xC3 || marker == 0xC5 || marker == 0xC6 || marker == 0xC7 ||
                    marker == 0xC9 || marker == 0xCA || marker == 0xCB ||
                    marker == 0xCD || marker == 0xCE || marker == 0xCF) {
                    return null
                }

                pos += segLen
                if (marker == 0xDA) {
                    if (!decodableSof) return null
                    seenSos = true
                }
            } else {
                if (buf[pos] == 0xFF.toByte()) {
                    val next = buf[pos + 1].toInt() and 0xFF
                    if (next == 0xD9) return Triple(pos + 2, width, height)
                    if (next == 0x00 || (next in 0xD0..0xD7) || next == 0xFF) {
                        pos += if (next == 0xFF) 1 else 2
                        continue
                    }
                    pos += 2
                    continue
                }
                pos++
            }
        }
        return null
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

    private fun parseExifRationalOrDouble(raw: String?): Double? {
        if (raw.isNullOrBlank()) return null
        val s = raw.trim()
        if (s.contains("/")) {
            val parts = s.split("/")
            if (parts.size == 2) {
                val num = parts[0].trim().toDoubleOrNull()
                val den = parts[1].trim().toDoubleOrNull()
                if (num != null && den != null && den != 0.0) {
                    return num / den
                }
            }
        }
        return s.toDoubleOrNull()
    }

    private fun extractExifSummaryFromUri(uri: Uri): String? {
        return try {
            val pfd = contentResolver.openFileDescriptor(uri, "r") ?: return null
            pfd.use { parcelFd ->
                val exif = android.media.ExifInterface(parcelFd.fileDescriptor)
                val model = exif.getAttribute(android.media.ExifInterface.TAG_MODEL)?.trim()
                    ?: exif.getAttribute(android.media.ExifInterface.TAG_MAKE)?.trim()
                    ?: ""
                val exposureStr = exif.getAttribute(android.media.ExifInterface.TAG_EXPOSURE_TIME)
                val fNumberStr = exif.getAttribute(android.media.ExifInterface.TAG_F_NUMBER)
                val isoStr = exif.getAttribute("PhotographicSensitivity")
                    ?: exif.getAttribute("ISOSpeedRatings")
                val focalStr = exif.getAttribute(android.media.ExifInterface.TAG_FOCAL_LENGTH)

                val parts = ArrayList<String>()
                if (model.isNotEmpty()) parts.add(model)

                val expVal = parseExifRationalOrDouble(exposureStr)
                if (expVal != null && expVal > 0.0) {
                    if (expVal < 1.0) {
                        val denom = Math.round(1.0 / expVal)
                        parts.add("1/${denom}s")
                    } else {
                        val formatted = if (expVal % 1.0 == 0.0) {
                            expVal.toInt().toString()
                        } else {
                            String.format(java.util.Locale.US, "%.1f", expVal)
                        }
                        parts.add("${formatted}s")
                    }
                }

                val fVal = parseExifRationalOrDouble(fNumberStr)
                if (fVal != null && fVal > 0.0) {
                    val formatted = if (fVal % 1.0 == 0.0) {
                        fVal.toInt().toString()
                    } else {
                        String.format(java.util.Locale.US, "%.1f", fVal)
                    }
                    parts.add("f/$formatted")
                }

                if (!isoStr.isNullOrBlank()) {
                    parts.add("ISO ${isoStr.trim()}")
                }

                val focVal = parseExifRationalOrDouble(focalStr)
                if (focVal != null && focVal > 0.0) {
                    val formatted = if (focVal % 1.0 == 0.0) {
                        focVal.toInt().toString()
                    } else {
                        String.format(java.util.Locale.US, "%.1f", focVal)
                    }
                    parts.add("${formatted}mm")
                }

                if (parts.isEmpty()) null else parts.joinToString(" • ")
            }
        } catch (e: Exception) {
            null
        }
    }
}
