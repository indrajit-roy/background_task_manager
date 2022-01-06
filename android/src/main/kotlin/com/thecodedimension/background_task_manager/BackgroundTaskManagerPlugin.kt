package com.thecodedimension.background_task_manager

import android.content.Context
import androidx.annotation.NonNull
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** BackgroundTaskManagerPlugin */
class BackgroundTaskManagerPlugin : FlutterPlugin {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    val methodCallHandler = BtmMethodCallHandler()
    val streamHandler = BtmStreamHandler()
    private val lifecycleOwner = CustomLifeCycleOwner()
    lateinit var workManager: WorkManager

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "background_task_manager")
        channel.setMethodCallHandler(methodCallHandler)
        eventChannel.setStreamHandler(streamHandler)
        workManager = WorkManager.getInstance(context)
        val oneTimeWorkRequest = OneTimeWorkRequestBuilder<BtmWorker>().build()
        workManager.enqueueUniqueWork("", ExistingWorkPolicy.REPLACE, oneTimeWorkRequest)
        lifecycleOwner.startListening()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        lifecycleOwner.stopListening()
    }
}
