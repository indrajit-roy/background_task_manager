package com.thecodedimension.background_task_manager

import android.content.Context
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.await

class BackgroundTaskManager(private val context: Context) : BackgroundTaskMangerInterface() {
    val workManager = WorkManager.getInstance(context)

    override fun executeTask(): Any? {
        val oneTimeWorkRequest = OneTimeWorkRequest.from(BtmWorker::class.java)
        val operation = workManager.enqueue(oneTimeWorkRequest)
        return operation
    }
}

abstract class BackgroundTaskMangerInterface {
    abstract fun executeTask(): Any?
}