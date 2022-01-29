package com.thecodedimension.background_task_manager

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import androidx.lifecycle.Observer
import androidx.work.WorkInfo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

val workStateMap = mapOf(
    "RUNNING" to WorkInfo.State.RUNNING,
    "ENQUEUED" to WorkInfo.State.ENQUEUED,
    "BLOCKED" to WorkInfo.State.BLOCKED,
    "CANCELLED" to WorkInfo.State.CANCELLED,
    "FAILED" to WorkInfo.State.FAILED,
    "SUCCEEDED" to WorkInfo.State.SUCCEEDED
)

val workProgressStates = listOf<WorkInfo.State>(
    WorkInfo.State.RUNNING,
    WorkInfo.State.ENQUEUED, WorkInfo.State.BLOCKED
)
val workResultStates = listOf<WorkInfo.State>(
    WorkInfo.State.SUCCEEDED,
    WorkInfo.State.FAILED,
    WorkInfo.State.CANCELLED
)


/** BackgroundTaskManagerPlugin */
class BackgroundTaskManagerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private val TAG = "BackgroundTaskManager"
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var progressEventChannel: EventChannel
    private lateinit var resultEventChannel: EventChannel
    private val progressStreamHandler = ProgressStreamHandler()
    private val resultStreamHandler = ResultStreamHandler()
    private lateinit var manager: BackgroundTaskManager

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        ContextHolder.setApplicationContext(context)
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "background_task_manager_method_channel")
        progressEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "background_task_manager_event_channel")
        resultEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "background_task_manager_event_channel_result")
        channel.setMethodCallHandler(this)
        progressEventChannel.setStreamHandler(progressStreamHandler)
        resultEventChannel.setStreamHandler(resultStreamHandler)
        manager = BackgroundTaskManager()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                try {
                    val success = manager.initialize()
                    if (success) {
                        manager.workProgressLiveData?.observeForever(runningTasksObserver)
                        manager.workResultLiveData?.observeForever(taskResultObserver)
                        result.success(true)
                    } else {
                        throw Exception("Initializing Background Task Manager Failed")
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "onMethodCall: initialize exception : $e")
                    result.success(false)
                } catch (e: Error) {
                    Log.d(TAG, "onMethodCall: initialize error : $e")
                    result.success(false)
                }
            }
            "getTasksByStatus" -> {
                if (manager.isInitialized) {
                    result.error("401", "Please call BackgroundTaskManager.singleton.init()", "Background Task Manager is not initialized.")
                    return
                }
                val status = (call.arguments as Map<*, *>)["status"] as List<*>?
                if (status == null) {
                    result.error("300", "Status passed from app was null", "")
                    return
                }
                CoroutineScope(Dispatchers.Main).launch(Dispatchers.Default) {
                    val tasks = manager.getTasksByStatus(status)
                    withContext(Dispatchers.Main) {
                        result.success(tasks)
                    }
                }
            }
            "executeTask" -> {
                try {
                    if (!manager.isInitialized) throw Exception("Background Task Manager is not initialized. Please call BackgroundTaskManager.singleton.init()")
                    val argsMap = call.arguments as Map<*, *>
                    val tag = argsMap["tag"] as String?
                    val callbackHandle: Long? = argsMap["callbackHandle"] as Long?
                    val taskHandle: Long? = argsMap["taskHandle"] as Long?
                    val args: HashMap<*, *>? = argsMap["args"] as HashMap<*, *>?
                    if (callbackHandle == null || taskHandle == null)
                        throw Exception("Callback handle : $callbackHandle or Task Handle : $taskHandle is null. Please pass a top level or a static function to callbackHandle / taskhandle.")
                    Log.d(TAG, "executeTask onMethodCall: args : $args")
                    CoroutineScope(Dispatchers.Main).launch(Dispatchers.Default) {
                        try {
                            val workId = manager.executeTask(callbackHandle, taskHandle, tag, args)
                            withContext(Dispatchers.Main) {
                                result.success(hashMapOf("taskId" to workId, "tag" to tag))
                            }
                        } catch (e: Exception) {
                            throw e;
                        } catch (e: Error) {
                            throw e;
                        }
                    }
                } catch (e: Error) {
                    result.error("", "An Error occurred. Task could not be Queued", "$e")
                } catch (e: Exception) {
                    result.error("", "An Exception occurred. Task could not be Queued", "$e")
                }
            }
            "getTasksWithUniqueWorkName" -> {
                try {
                    if (!manager.isInitialized) throw Exception("Background Task Manager is not initialized. Please call BackgroundTaskManager.singleton.init()")
                    CoroutineScope(Dispatchers.Main).launch(Dispatchers.Default) {
                        try {
                            val argsMap = call.arguments as Map<*, *>
                            val uniqueWorkName = argsMap["uniqueWorkName"] as String?
                            if (uniqueWorkName == null)
                                throw Exception("The uniqueWorkName passed was $uniqueWorkName")
                            val tasks = manager.getTasksWithUniqueWorkName(uniqueWorkName)
                            withContext(Dispatchers.Main) {
                                result.success(tasks)
                            }
                        } catch (e: Exception) {
                            throw e;
                        } catch (e: Error) {
                            throw e;
                        }
                    }
                } catch (e: Exception) {
                    result.error("", "An Exception occurred. Could not get tasks for tag.", "$e")
                } catch (e: Error) {
                    result.error("", "An Error occurred. Could not get tasks for tag.", "$e")
                }
            }
            "getTasksWithTag" -> {
                try {
                    if (!manager.isInitialized) throw Exception("Background Task Manager is not initialized. Please call BackgroundTaskManager.singleton.init()")
                    CoroutineScope(Dispatchers.Main).launch(Dispatchers.Default) {
                        try {
                            val argsMap = call.arguments as Map<*, *>
                            val tag = argsMap["tag"] as String?
                            if (tag == null)
                                throw Exception("The tag passed was $tag")
                            val tasks = manager.getTasksWithTag(tag)
                            withContext(Dispatchers.Main) {
                                result.success(tasks)
                            }
                        } catch (e: Exception) {
                            throw e;
                        } catch (e: Error) {
                            throw e;
                        }
                    }
                } catch (e: Exception) {
                    result.error("", "An Exception occurred. Could not get tasks for tag.", "$e")
                } catch (e: Error) {
                    result.error("", "An Error occurred. Could not get tasks for tag.", "$e")
                }
            }
            "enqueueUniqueTask" -> {
                try {
                    if (!manager.isInitialized) throw Exception("Background Task Manager is not initialized. Please call BackgroundTaskManager.singleton.init()")
                    val argsMap = call.arguments as Map<*, *>
                    val tag = argsMap["tag"] as String?
                    val uniqueWorkName = argsMap["uniqueWorkName"] as String?
                    val callbackHandle: Long? = argsMap["callbackHandle"] as Long?
                    val taskHandle: Long? = argsMap["taskHandle"] as Long?
                    val args: HashMap<*, *>? = argsMap["args"] as HashMap<*, *>?
                    if (callbackHandle == null || taskHandle == null || uniqueWorkName == null)
                        throw Exception("Callback handle : $callbackHandle or Task Handle : $taskHandle is null. Please pass a top level or a static function to callbackHandle / taskhandle.")
                    Log.d(TAG, "enqueueUniqueTask onMethodCall: uniqueWorkName : $uniqueWorkName, args : $args")
                    CoroutineScope(Dispatchers.Main).launch(Dispatchers.Default) {
                        try {
                            val workId = manager.enqueueUniqueTask(callbackHandle, taskHandle, uniqueWorkName, tag, args)
                            withContext(Dispatchers.Main) {
                                result.success(hashMapOf("taskId" to workId, "tag" to tag))
                            }
                        } catch (e: Exception) {
                            throw e;
                        } catch (e: Error) {
                            throw e;
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
        manager.workProgressLiveData?.removeObserver(runningTasksObserver)
        manager.workResultLiveData?.removeObserver(taskResultObserver)
        channel.setMethodCallHandler(null)
        progressEventChannel.setStreamHandler(null)
    }

    private val runningTasksObserver = Observer<MutableList<WorkInfo>>() {
        Log.d(TAG, "runningTasksObserver : filtered Info's Size : ${it.size}")
        it.forEach { info ->
            val backgroundEvent = BackgroundTaskManager.getBackgroundEventFromWorkInfo(info)
            if (backgroundEvent != null)
                progressStreamHandler.sendEvent(backgroundEvent)
        }
    }

    private val taskResultObserver = Observer<MutableList<WorkInfo>>() {
        Log.d(TAG, "taskResultObserver : filtered Info's Size : ${it.size}")
        it.forEach { info ->
            val backgroundEvent = BackgroundTaskManager.getBackgroundEventFromWorkInfo(info)
            if (backgroundEvent != null)
                resultStreamHandler.sendEvent(backgroundEvent)
        }
    }
}
