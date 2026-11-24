package com.caii.caii_pocket.scan

import android.content.Context
import org.opencv.android.OpenCVLoader
import org.opencv.core.Mat
import org.opencv.wechat_qrcode.WeChatQRCode
import java.io.File

/**
 * 微信开源扫码引擎（OpenCV wechat_qrcode 模块）单例。
 *
 * 4 个模型文件放在 assets/opencv_wechat/ 下，来源：
 * github.com/WeChatCV/WeChat_QrCode 的 models/ 目录
 * （detect.prototxt / detect.caffemodel / sr.prototxt / sr.caffemodel）。
 * WeChatQRCode 只接受文件路径，所以首次初始化时先拷到私有目录再加载。
 */
object WeChatScanEngine {

    private const val ASSET_DIR = "opencv_wechat"

    private val MODEL_FILES = listOf(
        "detect.prototxt",
        "detect.caffemodel",
        "sr.prototxt",
        "sr.caffemodel",
    )

    @Volatile
    private var detector: WeChatQRCode? = null

    val isReady: Boolean
        get() = detector != null

    /**
     * 加载 OpenCV native 库并从 assets 初始化模型。
     * 失败会抛异常，由 WeChatScanPlugin 捕获后回传 error 给 Flutter（不让初始化崩溃）。
     */
    @Synchronized
    fun init(context: Context) {
        if (detector != null) return
        // 4.9+ 官方推荐的 native 初始化方式
        if (!OpenCVLoader.initLocal()) {
            throw IllegalStateException("OpenCV native 库加载失败")
        }
        val dir = File(context.filesDir, ASSET_DIR).apply { mkdirs() }
        for (name in MODEL_FILES) {
            copyAssetIfNeeded(context, "$ASSET_DIR/$name", File(dir, name))
        }
        detector = WeChatQRCode(
            File(dir, "detect.prototxt").absolutePath,
            File(dir, "detect.caffemodel").absolutePath,
            File(dir, "sr.prototxt").absolutePath,
            File(dir, "sr.caffemodel").absolutePath,
        )
    }

    private fun copyAssetIfNeeded(context: Context, assetPath: String, target: File) {
        if (target.exists() && target.length() > 0) return
        context.assets.open(assetPath).use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        }
    }

    /** 识别一帧 BGR Mat 里的二维码，返回内容列表；引擎未就绪时返回空列表。 */
    fun detect(mat: Mat): List<String> {
        val d = detector ?: return emptyList()
        // WeChatQRCode.detectAndDecode(Mat, List<Mat>)：第二个参数是「检测到的二维码位置框」
        // （Mat 列表），解码出的字符串由返回值给出。
        val points = ArrayList<Mat>()
        return try {
            d.detectAndDecode(mat, points) ?: emptyList()
        } catch (t: Throwable) {
            emptyList()
        }
    }
}
