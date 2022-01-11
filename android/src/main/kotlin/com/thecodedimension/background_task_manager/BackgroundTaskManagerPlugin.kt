package com.thecodedimension.background_task_manager

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import androidx.lifecycle.Observer
import androidx.work.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext


/** BackgroundTaskManagerPlugin */
class BackgroundTaskManagerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private val TAG = "BackgroundTaskManager"
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var methodCallHandler: MethodChannel.MethodCallHandler
    val streamHandler = BtmStreamHandler()
    private val lifecycleOwner = CustomLifeCycleOwner()
    lateinit var workManager: WorkManager

    private val mainScope = CoroutineScope(Dispatchers.Main)

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        ContextHolder.setApplicationContext(context)
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "background_task_manager_method_channel")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "background_task_manager_event_channel")
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(streamHandler)
        workManager = WorkManager.getInstance(context)
        methodCallHandler = BtmMethodCallHandler(workManager = workManager)
        lifecycleOwner.startListening()
        mainScope.launch {
            withContext(Dispatchers.Default) {
                val infos = workManager.getWorkInfosForUniqueWork("testWork").await()
                val finishedWorkList = infos.filter {
                    it.state.isFinished
                }.toMutableList()
                withContext(Dispatchers.Main) {
                    workManager.getWorkInfosForUniqueWorkLiveData("testWork").observe(lifecycleOwner, Observer<MutableList<WorkInfo?>>() {
                        it.removeAll {
                            finishedWorkList.any { finishedInfo ->
                                finishedInfo.id == it?.id
                            }
                        }
                        Log.d(TAG, "onAttachedToEngine: filtered Infos : $it")
                        it.forEach { info ->
                            if (info?.state?.isFinished == true) {
                                val data = info.outputData.getString("test")
                                streamHandler.sendEvent(
                                    hashMapOf(
                                        "taskId" to IOUtilts.getTaskId(info.id.toString()),
                                        "event" to data
                                    )
                                )
                                finishedWorkList.add(info)
                            } else {
                                val progress = info?.progress?.getString("test")
                                if (progress != null)
                                    streamHandler.sendEvent(
                                        hashMapOf(
                                            "taskId" to IOUtilts.getTaskId(info.id.toString()),
                                            "event" to progress
                                        )
                                    )
                            }
                        }
                    })
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "executeTask" -> {
                try {
                    val taskId = (call.arguments as Map<*, *>)["taskId"] as String
                    val callbackHandle: Long? = (call.arguments as Map<*, *>)["callbackHandle"] as Long?
                    val taskHandle: Long? = (call.arguments as Map<*, *>)["taskHandle"] as Long?
                    val args: String? = (call.arguments as Map<*, *>)["args"] as String?
                    if (callbackHandle == null || taskHandle == null)
                        result.error("", "", "");

                    val oneTimeWorkRequest =
                        OneTimeWorkRequestBuilder<BtmWorker>().setInputData(
                            Data.Builder().putLong("callbackHandle", callbackHandle!!).putLong("taskHandle", taskHandle!!).putString("args", args)
                                .build()
                        ).build()
                    val op = workManager.enqueueUniqueWork("testWork", ExistingWorkPolicy.APPEND_OR_REPLACE, oneTimeWorkRequest)
                    op.state.observe(lifecycleOwner, Observer {
                        Log.e(TAG, "Worker State : $it")
                    });

                    mainScope.launch {
                        withContext(Dispatchers.IO) {
                            val output = op.result.await()
                            Log.d(TAG, "onMethodCall: WORKER RESULT $output")
                            withContext(Dispatchers.Main) {
                                IOUtilts.setTaskId(oneTimeWorkRequest.id.toString(), taskId)
                                result.success("Success from await $taskId ${oneTimeWorkRequest.id.toString()}")
                            }
                        }
                    }
                } catch (e: Error) {
                    result.error("", "An Error occurred. Task could not be Queued", "$e")
                } catch (e: Exception) {
                    result.error("", "An Exception occurred. Task could not be Queued", "$e")
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        lifecycleOwner.stopListening()
    }
}
