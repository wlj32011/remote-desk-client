package com.carriez.flutter_hbb

import androidx.core.content.FileProvider

// 单独起个类名，避免和插件里声明的 FileProvider 在清单合并时冲突
class BilinUpdateFileProvider : FileProvider()
