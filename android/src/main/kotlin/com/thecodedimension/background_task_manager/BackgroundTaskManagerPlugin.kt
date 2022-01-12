package com.thecodedimension.background_task_manager

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import androidx.lifecycle.LiveData
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
    lateinit var workManager: WorkManager
    private var liveData: LiveData<MutableList<WorkInfo>>? = null

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
        liveData = workManager.getWorkInfosLiveData(
            WorkQuery.Builder.fromStates(listOf(WorkInfo.State.ENQUEUED, WorkInfo.State.RUNNING)).build()
        )
        liveData?.observeForever(runningTasksObserver)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> result.success("Success")
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

                    mainScope.launch {
                        withContext(Dispatchers.IO) {
                            val output = op.result.await()
                            Log.d(TAG, "onMethodCall: WORKER RESULT $output")
                            withContext(Dispatchers.Main) {
                                IOUtils.setTaskId(oneTimeWorkRequest.id.toString(), taskId)
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
        liveData?.removeObserver(runningTasksObserver)
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    private val runningTasksObserver = Observer<MutableList<WorkInfo>>() {
        Log.d(TAG, "runningTasksObserver : filtered Infos Size : ${it.size}")
        it.forEach { info ->
            val progress = info.progress.getString("test")
            if (progress != null)
                streamHandler.sendEvent(
                    hashMapOf(
                        "taskId" to IOUtils.getTaskId(info.id.toString()),
                        "event" to progress
                    )
                )
        }
    }
}
