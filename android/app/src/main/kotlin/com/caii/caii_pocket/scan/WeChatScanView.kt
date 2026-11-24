package com.caii.caii_pocket.scan

import android.content.Context
import android.content.ContextWrapper
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.platform.PlatformView
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Size as CvSize
import org.opencv.imgproc.Imgproc
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * 微信引擎扫码视图（Flutter PlatformView）。
 *
 * CameraX 预览 + ImageAnalysis(YUV_420_888)：
 *   YUV -> NV21 -> OpenCV Mat(BGR) -> WeChatQRCode.detectAndDecode。
 * 识别到内容后通过 MethodChannel 回传 onResult，并自动暂停分析（等 resume 再扫）。
 * 支持物理长焦直切（CameraX 1.4 的 setPhysicalCameraId）、手电筒、变焦。
 */
class WeChatScanView(
    context: Context,
    private val plugin: WeChatScanPlugin,
) : FrameLayout(context), PlatformView {

    companion object {
        /** 两次识别之间的最小间隔（约 5fps 送检） */
        private const val ANALYZE_INTERVAL_MS = 200L

        /** 同一内容 3 秒内只回传一次 */
        private const val DEDUP_INTERVAL_MS = 3000L

        /** 送进引擎前把长边压到这个尺寸，控制单帧耗时 */
        private const val MAX_FRAME_EDGE = 960
    }

    private val previewView = PreviewView(context)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { mainHandler.post(it) }
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null

    /** 当前绑定的物理镜头 id；null = 逻辑主摄 */
    @Volatile
    private var physicalLensId: String? = null

    /** 识别成功后暂停分析，等 resume() 再继续 */
    @Volatile
    private var paused = false

    @Volatile
    private var released = false

    private var torchOn = false
    private var lastZoom = 1.0
    private var lastAnalyzeAt = 0L
    private val recentResults = HashMap<String, Long>()

    init {
        setBackgroundColor(Color.BLACK)
        previewView.layoutParams =
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        // 用 TextureView 渲染，在 Flutter PlatformView 合成模式下最稳
        previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        addView(previewView)
        mainHandler.post { startCamera() }
        plugin.attachView(this)
    }

    // ---------- 相机 ----------

    private fun findLifecycleOwner(): LifecycleOwner? {
        var c: Context = context
        while (c is ContextWrapper) {
            if (c is LifecycleOwner) return c
            c = c.baseContext
        }
        return null
    }

    private fun startCamera() {
        val owner = findLifecycleOwner()
        if (owner == null) {
            plugin.sendError("找不到 Activity 生命周期，相机启动失败")
            return
        }
        // processCameraProvider 要在主线程拿
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                bindUseCases(provider, owner)
            } catch (e: Exception) {
                plugin.sendError("相机启动失败：${e.message}")
            }
        }, mainExecutor)
    }

    private fun buildSelector(): CameraSelector {
        val id = physicalLensId ?: return CameraSelector.DEFAULT_BACK_CAMERA
        return try {
            // CameraX 1.4+ 支持直选逻辑多摄里的物理镜头（长焦）
            CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                .setPhysicalCameraId(id)
                .build()
        } catch (e: Exception) {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
    }

    private fun bindUseCases(provider: ProcessCameraProvider, owner: LifecycleOwner) {
        if (released) return
        provider.unbindAll()

        val preview = Preview.Builder().build()
        preview.setSurfaceProvider(previewView.surfaceProvider)

        val analysis = ImageAnalysis.Builder()
            .setResolutionSelector(
                ResolutionSelector.Builder()
                    .setResolutionStrategy(
                        ResolutionStrategy(
                            Size(1280, 720),
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                        ),
                    )
                    .build(),
            )
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
        analysis.setAnalyzer(analysisExecutor, FrameAnalyzer())

        try {
            camera = provider.bindToLifecycle(owner, buildSelector(), preview, analysis)
            // 重绑后恢复手电筒 / 变焦状态
            if (torchOn) camera?.cameraControl?.enableTorch(true)
            if (lastZoom != 1.0) camera?.cameraControl?.setZoomRatio(lastZoom.toFloat())
        } catch (e: Exception) {
            // 物理长焦直绑失败（机型不支持）-> 退回逻辑主摄
            try {
                camera = provider.bindToLifecycle(
                    owner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis,
                )
            } catch (e2: Exception) {
                plugin.sendError("相机绑定失败：${e2.message}")
            }
        }
    }

    // ---------- 帧分析 ----------

    private inner class FrameAnalyzer : ImageAnalysis.Analyzer {
        override fun analyze(image: ImageProxy) {
            val now = System.currentTimeMillis()
            if (released || paused || !WeChatScanEngine.isReady ||
                now - lastAnalyzeAt < ANALYZE_INTERVAL_MS
            ) {
                image.close()
                return
            }
            lastAnalyzeAt = now
            val rotation = image.imageInfo.rotationDegrees
            val bgr = try {
                yuvToBgr(image)
            } finally {
                image.close()
            }
            try {
                val frame = uprightAndScale(bgr, rotation)
                bgr.release()
                val codes = WeChatScanEngine.detect(frame)
                frame.release()
                val text = codes.firstOrNull { it.isNotBlank() } ?: return
                synchronized(recentResults) {
                    // 去重：同一内容 3 秒内只回传一次
                    val last = recentResults[text]
                    if (last != null && now - last < DEDUP_INTERVAL_MS) return
                    recentResults.entries.removeAll { now - it.value >= DEDUP_INTERVAL_MS }
                    recentResults[text] = now
                }
                // 识别成功：暂停分析，等 Flutter 侧「重新扫描」时 resume
                paused = true
                mainHandler.post { plugin.sendResult(text) }
            } catch (e: Exception) {
                // 单帧识别失败不影响下一帧
            }
        }
    }

    /** YUV_420_888 -> NV21 -> BGR Mat，注意 rowStride/pixelStride 可能带 padding。 */
    private fun yuvToBgr(image: ImageProxy): Mat {
        val width = image.width
        val height = image.height
        val ySize = width * height
        val nv21 = ByteArray(ySize + ySize / 2)

        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]

        // Y 平面：rowStride 大于 width 时逐行拷，跳过行尾 padding
        val yBuffer = yPlane.buffer
        if (yPlane.rowStride == width) {
            yBuffer.get(nv21, 0, ySize)
        } else {
            var pos = 0
            val row = ByteArray(width)
            for (i in 0 until height) {
                yBuffer.position(i * yPlane.rowStride)
                yBuffer.get(row)
                System.arraycopy(row, 0, nv21, pos, width)
                pos += width
            }
        }

        // UV 平面重排成 NV21 交错格式（V 在前、U 在后）
        val chromaHeight = height / 2
        val chromaWidth = width / 2
        val vBuffer = vPlane.buffer
        val uBuffer = uPlane.buffer
        val vRowStride = vPlane.rowStride
        val uRowStride = uPlane.rowStride
        val vPixStride = vPlane.pixelStride
        val uPixStride = uPlane.pixelStride
        var pos = ySize
        for (row in 0 until chromaHeight) {
            var vIndex = row * vRowStride
            var uIndex = row * uRowStride
            repeat(chromaWidth) {
                nv21[pos++] = vBuffer.get(vIndex)
                nv21[pos++] = uBuffer.get(uIndex)
                vIndex += vPixStride
                uIndex += uPixStride
            }
        }

        val yuv = Mat(height + height / 2, width, CvType.CV_8UC1)
        yuv.put(0, 0, nv21)
        val bgr = Mat()
        Imgproc.cvtColor(yuv, bgr, Imgproc.COLOR_YUV2BGR_NV21)
        yuv.release()
        return bgr
    }

    /** 旋转到屏幕方向并压到合适尺寸，返回新 Mat（原 Mat 被 release）。 */
    private fun uprightAndScale(src: Mat, rotationDegrees: Int): Mat {
        val rotated = Mat()
        when (rotationDegrees) {
            90 -> Core.rotate(src, rotated, Core.ROTATE_90_CLOCKWISE)
            180 -> Core.rotate(src, rotated, Core.ROTATE_180)
            270 -> Core.rotate(src, rotated, Core.ROTATE_90_COUNTERCLOCKWISE)
            else -> src.copyTo(rotated)
        }
        src.release()
        val longer = max(rotated.rows(), rotated.cols())
        if (longer > MAX_FRAME_EDGE) {
            val scale = MAX_FRAME_EDGE.toDouble() / longer
            val resized = Mat()
            Imgproc.resize(
                rotated,
                resized,
                CvSize(rotated.cols() * scale, rotated.rows() * scale),
            )
            rotated.release()
            return resized
        }
        return rotated
    }

    // ---------- Flutter 侧控制 ----------

    fun setZoom(ratio: Double) {
        lastZoom = ratio
        mainHandler.post { camera?.cameraControl?.setZoomRatio(ratio.toFloat()) }
    }

    fun setTorch(on: Boolean) {
        torchOn = on
        mainHandler.post { camera?.cameraControl?.enableTorch(on) }
    }

    /** 切换物理镜头；null = 回到逻辑主摄。不支持直切时退回主摄（变焦兜底）。 */
    fun setPhysicalLens(id: String?) {
        if (physicalLensId == id) return
        physicalLensId = id
        paused = false
        mainHandler.post {
            val provider = cameraProvider
            val owner = findLifecycleOwner()
            if (!released && provider != null && owner != null) {
                bindUseCases(provider, owner)
            }
        }
    }

    /** 恢复分析（Flutter 侧「重新扫描」时调用）。 */
    fun resumeScan() {
        paused = false
        synchronized(recentResults) { recentResults.clear() }
    }

    fun releaseCamera() {
        if (released) return
        released = true
        mainHandler.post {
            try {
                cameraProvider?.unbindAll()
            } catch (e: Exception) {
                // 已经被销毁时忽略
            }
            camera = null
            cameraProvider = null
        }
        analysisExecutor.shutdown()
        plugin.detachView(this)
    }

    override fun getView(): View = this

    override fun dispose() {
        releaseCamera()
    }
}
