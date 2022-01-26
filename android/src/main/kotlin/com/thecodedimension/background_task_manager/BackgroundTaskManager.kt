package com.thecodedimension.background_task_manager

import androidx.lifecycle.LiveData
import androidx.work.*

class BackgroundTaskManager {
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
        val infos = workManager.getWorkInfos(WorkQuery.Builder.fromStates(statusList.toMutableList()).build()).await()
        val taskInfoList: MutableList<HashMap<String, Any?>> = mutableListOf()
        infos.forEach { info ->
            val backgroundEvent = getBackgroundEventFromWorkInfo(info)
            if (backgroundEvent != null)
                taskInfoList.add(backgroundEvent)
        }
        return taskInfoList.toList()
    }

    suspend fun executeTask(callbackHandle: Long, taskHandle: Long, tag: String? = null, args: HashMap<*, *>? = null): String {
        try {
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
            throw e;
        } catch (e: Error) {
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
                    hashMap[entry.key] = entry.value
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