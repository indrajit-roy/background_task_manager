package com.thecodedimension.background_task_manager

import android.content.SharedPreferences
import android.util.Log

object BackgroundPreferences {

    private const val TAG = "IOUtils"
    private var taskPrefs: SharedPreferences? = null
    private var tagPrefs: SharedPreferences? = null

    init {
        taskPrefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFS_KEY_TASK, 0)
        tagPrefs = ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFS_KEY_TAG, 0)
    }

    fun setTaskInfo(workId: String, taskId: String, tag: String? = null) {
        if (ContextHolder.getApplicationContext() == null) return;
        taskPrefs?.edit()?.putString(workId, taskId)?.apply()
        if (tag != null)
            tagPrefs?.edit()?.putString(workId, tag)?.apply();
    }

    fun getTaskInfo(workId: String): HashMap<String, String?>? {
        if (ContextHolder.getApplicationContext() == null) return null;
        val taskId = taskPrefs?.getString(workId, null)
        val tag = tagPrefs?.getString(workId, null)
        if (taskId == null && tag == null)
            return null
        return hashMapOf(
            "taskId" to taskId,
            "tag" to tag
        )
    }

    fun getTaskId(workId: String): String? {
        if (ContextHolder.getApplicationContext() == null) return null;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFS_KEY_TASK, 0)
        val taskId = prefs?.getString(workId, "null");
        Log.d(TAG, "getTaskId: Prefs Map : ${prefs?.all}")
        Log.d(TAG, "getTaskId: $taskId")
        return if (taskId == "null") null else taskId
    }

    fun getWorkId(taskId: String): String? {
        if (ContextHolder.getApplicationContext() == null) return null;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFS_KEY_TASK, 0)
        val values = prefs?.all?.entries

        val entry = values?.filter {
            it.value == taskId
        }
        return entry?.last()?.key
    }
}