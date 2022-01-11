package com.thecodedimension.background_task_manager

import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BtmMethodCallHandler(private val workManager: WorkManager) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "executeTask" -> {
                try {
                    val oneTimeWorkRequest = OneTimeWorkRequestBuilder<BtmWorker>().build()
                    val op = workManager.enqueueUniqueWork("testWork", ExistingWorkPolicy.REPLACE, oneTimeWorkRequest)
                    result.success("Queued")
                } catch (e: Error) {
                    result.error("", "An Error occurred. Task could not be Queued", "$e")
                } catch (e: Exception) {
                    result.error("", "An Exception occurred. Task could not be Queued", "$e")
                }
            }
            else -> result.notImplemented()
        }
    }
}