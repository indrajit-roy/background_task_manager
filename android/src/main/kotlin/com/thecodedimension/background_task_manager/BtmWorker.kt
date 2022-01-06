package com.thecodedimension.background_task_manager

import android.content.Context
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters


class BtmWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        TODO("Not yet implemented")
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