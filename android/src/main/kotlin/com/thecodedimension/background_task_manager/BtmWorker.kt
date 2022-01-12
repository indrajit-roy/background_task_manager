package com.thecodedimension.background_task_manager

import android.content.Context
import android.content.res.AssetManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.WorkerParameters
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


class BtmWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    private val TAG = "BtmWorker"

    private var backgroundFlutterEngine: FlutterEngine? = null
    private val isCallbackDispatcherReady = AtomicBoolean(false)
    private var backgroundChannel: MethodChannel? = null
    private val methodCallHandler = MethodCallHandler()
    private val completer = CompletableDeferred<Result>()
    private val flutterEngineCompleter = CompletableDeferred<Unit>()


    private fun isNotRunning(): Boolean {
        return !isCallbackDispatcherReady.get()
    }

    inner class MethodCallHandler : MethodChannel.MethodCallHandler {
        override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "sendEvent" -> {
                    Log.d(TAG, "onMethodCall: sendEvent ${call.arguments}")
                    setProgressAsync(Data.Builder().putString("test", call.arguments as String).build())
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
        val args = inputData.getString("args")
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
            backgroundChannel?.invokeMethod("executeCallback", hashMapOf("taskHandle" to taskHandle, "args" to args), resultHandler)
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
            if (completer.isActive)
                completer.complete(
                    Result.success(
                        Data.Builder().putString("test", result as String).build()
                    )
                )
        }

        override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
            Log.d(TAG, "doWork: task error")
            if (completer.isActive)
                completer.complete(
                    Result.failure(
                        Data.Builder().putString("test", "test failure : $errorCode, $errorMessage, $errorDetails").build()
                    )
                )
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

class CustomLifeCycleOwner : LifecycleOwner {
    private val mLifecycleRegistry: LifecycleRegistry = LifecycleRegistry(this)
    fun stopListening() {
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
    }

    fun startListening() {
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
    }

    override fun getLifecycle(): Lifecycle {
        Log.i("CustomLifeCycleOwner", "Returning registry!!")
        return mLifecycleRegistry
    }

    init {
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
    }
}