package com.thecodedimension.background_task_manager

import android.content.Context
import android.content.res.AssetManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean


class BackgroundTaskManagerWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    private val TAG = "BtmWorker"

    private var backgroundFlutterEngine: FlutterEngine? = null
    private val isCallbackDispatcherReady = AtomicBoolean(false)
    private var backgroundChannel: MethodChannel? = null
    private val methodCallHandler = MethodCallHandler()
    private val completer = CompletableDeferred<Result>()
    private val flutterEngineCompleter = CompletableDeferred<Unit>()

    companion object {
        fun addFieldToData(dataBuilder: Data.Builder, entry: MutableMap.MutableEntry<out Any, out Any>): Data.Builder {
            if (entry.value is HashMap<*, *>) {
                return when ((entry.value as HashMap<*, *>)["platformKey"]) {
                    "String" -> {
                        dataBuilder.putString(entry.key as String, (entry.value as HashMap<*, *>)["value"] as String)
                        dataBuilder
                    }
                    "int" -> {
                        dataBuilder.putInt(entry.key as String, (entry.value as HashMap<*, *>)["value"] as Int)
                        dataBuilder
                    }
                    "double" -> {
                        dataBuilder.putDouble(entry.key as String, (entry.value as HashMap<*, *>)["value"] as Double)
                        dataBuilder
                    }
                    "bool" -> {
                        dataBuilder.putBoolean(entry.key as String, (entry.value as HashMap<*, *>)["value"] as Boolean)
                        dataBuilder
                    }
                    "List<String>" -> {
                        dataBuilder.putStringArray(
                            entry.key as String,
                            ((entry.value as HashMap<*, *>)["value"] as List<String>).toTypedArray()
                        )
                        dataBuilder
                    }
                    "List<double>" -> {
                        dataBuilder.putDoubleArray(
                            entry.key as String,
                            ((entry.value as HashMap<*, *>)["value"] as List<Double>).toDoubleArray()
                        )
                        dataBuilder
                    }
                    "List<int>" -> {
                        dataBuilder.putIntArray(
                            entry.key as String,
                            ((entry.value as HashMap<*, *>)["value"] as List<Int>).toIntArray()
                        )
                        dataBuilder
                    }
                    "List<bool>" -> {
                        dataBuilder.putBooleanArray(
                            entry.key as String,
                            ((entry.value as HashMap<*, *>)["value"] as List<Boolean>).toBooleanArray()
                        )
                        dataBuilder
                    }
                    else -> dataBuilder
                }
            } else return dataBuilder;
        }
    }


    private fun isNotRunning(): Boolean {
        return !isCallbackDispatcherReady.get()
    }

    inner class MethodCallHandler : MethodChannel.MethodCallHandler {
        override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "sendEvent" -> {
                    Log.d(TAG, "onMethodCall: sendEvent ${call.arguments} of type ${call.arguments.javaClass}")
                    val progress = call.arguments as HashMap<*, *>
                    val dataBuilder = Data.Builder()
                    progress.entries.forEach {
                        addFieldToData(dataBuilder, it)
                    }
                    setProgressAsync(dataBuilder.build())
                }
            }
        }

    }

    private fun initializeMethodChannel(isolate: BinaryMessenger) {
        backgroundChannel = MethodChannel(isolate, "background_task_manager_worker_method_channel")
        backgroundChannel!!.setMethodCallHandler(methodCallHandler)
    }

    override suspend fun doWork(): Result {
        val shellArgs: FlutterShellArgs? = null
        val callbackHandle = inputData.getLong("callbackHandle", (-1).toLong())
        val taskHandle = inputData.getLong("taskHandle", (-1).toLong())
        val args = inputData.keyValueMap
        val argsHashMap = hashMapOf<String, Any?>()
        Log.d(TAG, "doWork: worker input data : $args")
        args.entries.forEach {
            if (it.key == "callbackHandle" || it.key == "taskHandle") return@forEach
            argsHashMap[it.key] = it.value
        }
        Log.d(TAG, "doWork: args HashMap : $argsHashMap")
        if (backgroundFlutterEngine != null) {
            Log.e(TAG, "Background isolate already started.")
            return Result.failure()
        }
        if (callbackHandle == (-1).toLong()) {
            return Result.failure()
        }
        startBackgroundFlutterEngine(callbackHandle, shellArgs)
        flutterEngineCompleter.await()
        Log.d(TAG, "doWork: Started Engine bgChannel = $backgroundChannel, taskHandle = $taskHandle")
        if (backgroundChannel == null || taskHandle == (-1).toLong()) {
            backgroundFlutterEngine?.destroy()
            backgroundFlutterEngine = null
            return Result.failure()
        }
        Log.d(TAG, "doWork: Attempt to call callback")
        withContext(Dispatchers.Main) {
            backgroundChannel?.invokeMethod("executeCallback", hashMapOf("taskHandle" to taskHandle, "args" to argsHashMap), resultHandler)
        }
        val output = completer.await()
        withContext(Dispatchers.Main) {
            backgroundFlutterEngine?.destroy()
            backgroundFlutterEngine = null
        }
        return output
    }

    private fun startBackgroundFlutterEngine(callbackHandle: Long, shellArgs: FlutterShellArgs?): Unit {
        val mainHandler = Handler(Looper.getMainLooper())
        val myRunnable = Runnable {
            val flutterLoader = FlutterLoader()
            flutterLoader.startInitialization(applicationContext)
            flutterLoader.ensureInitializationCompleteAsync(
                applicationContext,
                null,
                mainHandler
            ) {
                val appBundlePath = flutterLoader.findAppBundlePath()
                val assets: AssetManager = applicationContext.assets
                if (isNotRunning()) {
                    backgroundFlutterEngine = if (shellArgs != null) {
                        io.flutter.Log.e(
                            TAG, "Creating background FlutterEngine instance, with args: "
                                    + shellArgs.toArray().contentToString()
                        )
                        FlutterEngine(
                            applicationContext, shellArgs.toArray()
                        )
                    } else {
                        io.flutter.Log.e(
                            TAG,
                            "Creating background FlutterEngine instance. callback handle $callbackHandle"
                        )
                        FlutterEngine(applicationContext)
                    }
                    val flutterCallback =
                        FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
                    val executor: DartExecutor = backgroundFlutterEngine!!.dartExecutor
                    initializeMethodChannel(executor)
                    val dartCallback =
                        DartExecutor.DartCallback(assets, appBundlePath, flutterCallback)
                    executor.executeDartCallback(dartCallback)
                    isCallbackDispatcherReady.set(true)
                    flutterEngineCompleter.complete(Unit)
                }
            }
        }
        mainHandler.post(myRunnable)
    }

    private val resultHandler = object : MethodChannel.Result {
        override fun success(result: Any?) {
            Log.d(TAG, "doWork: task success")
            if (completer.isActive) {
                val progress = result as HashMap<*, *>
                val dataBuilder = Data.Builder()
                progress.entries.forEach {
                    addFieldToData(dataBuilder, it)
                }
                completer.complete(Result.success(dataBuilder.build()))
            }
        }

        override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
            Log.d(TAG, "doWork: task error code=$errorCode message=$errorMessage details=$errorDetails")
            if (completer.isActive)
                completer.complete(Result.failure(workDataOf("result" to errorMessage)))
        }

        override fun notImplemented() {
            Log.d(TAG, "doWork: task not implemented")
            if (completer.isActive)
                completer.complete(
                    Result.failure(
                        Data.Builder()
                            .putString("test", "test failure internal. Method not implemented. Check hardcoded / constant method call names")
                            .build()
                    )
                )
        }
    }
}