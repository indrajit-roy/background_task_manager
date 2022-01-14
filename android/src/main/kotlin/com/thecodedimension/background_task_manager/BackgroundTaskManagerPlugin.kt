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

val workStateMap = mapOf<String, WorkInfo.State>(
    "RUNNING" to WorkInfo.State.RUNNING,
    "ENQUEUED" to WorkInfo.State.ENQUEUED,
    "BLOCKED" to WorkInfo.State.BLOCKED,
    "CANCELLED" to WorkInfo.State.CANCELLED,
    "FAILED" to WorkInfo.State.FAILED,
    "SUCCEEDED" to WorkInfo.State.SUCCEEDED
)

/** BackgroundTaskManagerPlugin */
class BackgroundTaskManagerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private val TAG = "BackgroundTaskManager"
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var progressEventChannel: EventChannel
    private lateinit var resultEventChannel: EventChannel
    private lateinit var methodCallHandler: MethodChannel.MethodCallHandler
    private val progressStreamHandler = ProgressStreamHandler()
    private val resultStreamHandler = ResultStreamHandler()
    private lateinit var workManager: WorkManager
    private var workProgressLiveData: LiveData<MutableList<WorkInfo>>? = null
    private var workResultLiveData: LiveData<MutableList<WorkInfo>>? = null

    private val mainScope = CoroutineScope(Dispatchers.Main)

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        ContextHolder.setApplicationContext(context)
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "background_task_manager_method_channel")
        progressEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "background_task_manager_event_channel")
        resultEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "background_task_manager_event_channel_result")
        channel.setMethodCallHandler(this)
        progressEventChannel.setStreamHandler(progressStreamHandler)
        resultEventChannel.setStreamHandler(resultStreamHandler)
        workManager = WorkManager.getInstance(context)
        methodCallHandler = BtmMethodCallHandler(workManager = workManager)
        workProgressLiveData = workManager.getWorkInfosLiveData(
            WorkQuery.Builder.fromStates(listOf(WorkInfo.State.ENQUEUED, WorkInfo.State.RUNNING, WorkInfo.State.BLOCKED)).build()
        )
        workResultLiveData = workManager.getWorkInfosLiveData(
            WorkQuery.Builder.fromStates(listOf(WorkInfo.State.SUCCEEDED, WorkInfo.State.FAILED, WorkInfo.State.CANCELLED)).build()
        )
        workProgressLiveData?.observeForever(runningTasksObserver)
        workResultLiveData?.observeForever(taskResultObserver)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                result.success(true)
            }
            "getTasksByStatus" -> {
                val status = (call.arguments as Map<*, *>)["status"] as String?
                if (status == null)
                    result.error("300", "Status passed from app was null", "")

                workManager.getWorkInfos(WorkQuery.Builder.fromStates(listOf(workStateMap[status])).build()).also {
                    it.addListener({
                        val taskIdList = it.get().map { info ->
                            val taskInfo = IOUtils.getTaskInfo(info.id.toString())
                            if (taskInfo == null)
                                null
                            else
                                taskInfo["taskId"]
                        }
                        result.success(taskIdList)
                    }, { command -> command.run() })
                }
            }
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
                    val output = op.result.also {
                        it.addListener({
                            IOUtils.setTaskInfo(oneTimeWorkRequest.id.toString(), taskId)
                            result.success("Success from await $taskId ${oneTimeWorkRequest.id}")
                        }, { command -> command?.run() })
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
        workProgressLiveData?.removeObserver(runningTasksObserver)
        workResultLiveData?.removeObserver(taskResultObserver)
        channel.setMethodCallHandler(null)
        progressEventChannel.setStreamHandler(null)
    }

    private val runningTasksObserver = Observer<MutableList<WorkInfo>>() {
        Log.d(TAG, "runningTasksObserver : filtered Infos Size : ${it.size}")
        it.forEach { info ->
            val progress = info.progress.keyValueMap
            if (progress.isNotEmpty()) {
                val taskInfo = IOUtils.getTaskInfo(info.id.toString())
                Log.d(TAG, "taskInfo : $taskInfo")
                if (taskInfo == null) return@forEach
                val hashMap = hashMapOf<String, Any?>()
                progress.entries.forEach { entry ->
                    hashMap[entry.key] = entry.value
                }
                progressStreamHandler.sendEvent(
                    hashMapOf(
                        "taskId" to taskInfo["taskId"],
                        "event" to hashMap
                    )
                )
            }
        }
    }
    private val taskResultObserver = Observer<MutableList<WorkInfo>>() {
        Log.d(TAG, "taskResultObserver : filtered Infos Size : ${it.size}")
        it.forEach { info ->
            val result = info.outputData.keyValueMap
            if (result.isNotEmpty()) {
                val taskInfo = IOUtils.getTaskInfo(info.id.toString())
                Log.d(TAG, "taskInfo : $taskInfo")
                if (taskInfo == null) return@forEach
                val hashMap = hashMapOf<String, Any?>()
                result.entries.forEach { entry ->
                    hashMap[entry.key] = entry.value
                }
                resultStreamHandler.sendEvent(
                    hashMapOf(
                        "taskId" to taskInfo["taskId"],
                        "result" to hashMap
                    )
                )
            }
        }
    }
}
