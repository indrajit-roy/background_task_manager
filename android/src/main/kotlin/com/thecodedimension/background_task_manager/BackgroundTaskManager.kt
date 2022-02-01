package com.thecodedimension.background_task_manager

import android.util.Log
import androidx.lifecycle.LiveData
import androidx.work.*

class BackgroundTaskManager {
    private val TAG = "BackgroundTaskManager";
    private lateinit var workManager: WorkManager
    var workProgressLiveData: LiveData<MutableList<WorkInfo>>? = null
    var workResultLiveData: LiveData<MutableList<WorkInfo>>? = null
    var isInitialized = false

    fun initialize(): Boolean {
        try {
            val context = ContextHolder.getApplicationContext() ?: throw Exception("Context is null")
            workManager = WorkManager.getInstance(context)
            workProgressLiveData = workManager.getWorkInfosLiveData(
                WorkQuery.Builder.fromStates(listOf(WorkInfo.State.ENQUEUED, WorkInfo.State.RUNNING, WorkInfo.State.BLOCKED)).build()
            )
            workResultLiveData = workManager.getWorkInfosLiveData(
                WorkQuery.Builder.fromStates(listOf(WorkInfo.State.SUCCEEDED, WorkInfo.State.FAILED, WorkInfo.State.CANCELLED)).build()
            )
            isInitialized = true
            return isInitialized
        } catch (e: Exception) {
            throw e;
        }
    }

    suspend fun getTasksByStatus(statusListInput: List<*>): List<HashMap<String, Any?>> {
        val statusList = statusListInput.map {
            workStateMap[it]
        }
        Log.d(TAG, "getTasksByStatus: input : $statusListInput")
        Log.d(TAG, "getTasksByStatus: statusList : $statusList")
        val infos = workManager.getWorkInfos(WorkQuery.Builder.fromStates(statusList.toMutableList()).build()).await()
        Log.d(TAG, "getTasksByStatus: infos : $infos")
        val taskInfoList: MutableList<HashMap<String, Any?>> = mutableListOf()
        infos.forEach { info ->
            val backgroundEvent = getBackgroundEventFromWorkInfo(info)
            if (backgroundEvent != null)
                taskInfoList.add(backgroundEvent)
        }
        Log.d(TAG, "getTasksByStatus: taskInfoList : $taskInfoList")
        return taskInfoList.toList()
    }

    suspend fun executeTask(callbackHandle: Long, taskHandle: Long, tag: String? = null, args: HashMap<*, *>? = null): String {
        try {
            val dataBuilder = Data.Builder()
            val myTotalMemoryBefore = Runtime.getRuntime().totalMemory()
            args?.entries?.forEach {
            Log.d(TAG, "executeTask: size of args : ${args.size}")
                Log.d(TAG, "addFieldToData: ${(it.value as HashMap<*, *>)["value"]?.javaClass}")
                if ((it.value as HashMap<*, *>)["value"] is List<*>) {
                    Log.d(TAG, "addFieldToData: ${((it.value as HashMap<*, *>)["value"] as List<*>)[0]?.javaClass}")
                }
                BackgroundTaskManagerWorker.addFieldToData(dataBuilder, it)
            }
            val data = dataBuilder.putLong("callbackHandle", callbackHandle).putLong("taskHandle", taskHandle)
                .build()
            val myTotalMemoryAfter = Runtime.getRuntime().totalMemory()
            val myHashMapMemory = myTotalMemoryAfter - myTotalMemoryBefore
            val oneTimeWorkRequestBuilder = OneTimeWorkRequestBuilder<BackgroundTaskManagerWorker>().setInputData(data)
            if (tag != null)
                oneTimeWorkRequestBuilder.addTag(tag)

            val oneTimeWorkRequest = oneTimeWorkRequestBuilder.build()
            workManager.enqueue(oneTimeWorkRequest).await()
            BackgroundPreferences.setTaskInfo(oneTimeWorkRequest.id.toString(), oneTimeWorkRequest.id.toString(), tag = tag)
            return "${oneTimeWorkRequest.id}"
        } catch (e: Exception) {
            throw e;
        } catch (e: Error) {
            throw e;
        }
    }

    suspend fun enqueueUniqueTask(
        callbackHandle: Long,
        taskHandle: Long,
        uniqueWorkName: String,
        tag: String? = null,
        args: HashMap<*, *>? = null
    ): String {
        try {
            Log.d(TAG, "enqueueUniqueTask: start")
            val dataBuilder = Data.Builder()
            args?.entries?.forEach {
                BackgroundTaskManagerWorker.addFieldToData(dataBuilder, it)
            }
            val oneTimeWorkRequestBuilder = OneTimeWorkRequestBuilder<BackgroundTaskManagerWorker>().setInputData(
                dataBuilder.putLong("callbackHandle", callbackHandle).putLong("taskHandle", taskHandle)
                    .build()
            )
            if (tag != null)
                oneTimeWorkRequestBuilder.addTag(tag)

            val oneTimeWorkRequest = oneTimeWorkRequestBuilder.build()
            workManager.enqueueUniqueWork(uniqueWorkName, ExistingWorkPolicy.APPEND, oneTimeWorkRequest).await()
            BackgroundPreferences.setTaskInfo(oneTimeWorkRequest.id.toString(), oneTimeWorkRequest.id.toString(), tag = tag)
            return "${oneTimeWorkRequest.id}"
        } catch (e: Exception) {
            Log.d(TAG, "enqueueUniqueTask: exception $e")
            throw e;
        } catch (e: Error) {
            Log.d(TAG, "enqueueUniqueTask: error $e")
            throw e;
        }
    }

    suspend fun getTasksWithTag(tag: String): List<HashMap<String, Any?>?> {
        val tasks = workManager.getWorkInfosByTag(tag).await()
        return tasks.map {
            getBackgroundEventFromWorkInfo(it)
        }.toList()
    }

    suspend fun getTasksWithUniqueWorkName(uniqueWorkName: String): List<HashMap<String, Any?>?> {
        val tasks = workManager.getWorkInfosForUniqueWork(uniqueWorkName).await()
        return tasks.map {
            getBackgroundEventFromWorkInfo(it)
        }.toList()
    }

    companion object {
        fun getBackgroundEventFromWorkInfo(info: WorkInfo): HashMap<String, Any?>? {
            val progress = if (workProgressStates.any { it == info.state }) info.progress.keyValueMap else info.outputData.keyValueMap

            if (progress.isNotEmpty()) {
                val taskInfo = BackgroundPreferences.getTaskInfo(info.id.toString()) ?: return null
                val hashMap = hashMapOf<String, Any?>()
                progress.entries.forEach { entry ->
                    if (entry.value is Array<*>) {
                        hashMap[entry.key] = (entry.value as Array<*>).toList()
                    } else {
                        hashMap[entry.key] = entry.value
                    }
                }
                return hashMapOf(
                    "taskId" to "${info.id}",
                    "tag" to taskInfo["tag"],
                    "status" to workStateMap.entries.firstOrNull { entry -> entry.value == info.state }?.key,
                    "event" to hashMap
                )
            }
            return null
        }
    }
}