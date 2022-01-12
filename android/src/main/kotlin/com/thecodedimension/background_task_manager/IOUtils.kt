package com.thecodedimension.background_task_manager

import android.util.Log

object IOUtils {

    private const val TAG = "IOUtilts"

    fun getCallbackDispatcher(): Long? {
        if (ContextHolder.getApplicationContext() == null) return null;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFERENCES_KEY, 0)
        return prefs?.getLong(Constants.Strings.CALLBACK_HANDLE_KEY, (-1).toLong())
    }

    fun setCallbackDispatcher(callbackHandle: Long) {
        if (ContextHolder.getApplicationContext() == null) return;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFERENCES_KEY, 0)
        prefs?.edit()?.putLong(Constants.Strings.CALLBACK_HANDLE_KEY, callbackHandle)?.apply()
    }

    fun setTaskId(workId: String, taskId: String) {
        if (ContextHolder.getApplicationContext() == null) return;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFERENCES_KEY, 0)
        prefs?.edit()?.putString(workId, taskId)?.apply();
    }

    fun setTaskInfo(workId: String, taskId: String, taskType: String) {
        if (ContextHolder.getApplicationContext() == null) return;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFERENCES_KEY, 0)
        val set = mutableSetOf<String>(taskId, taskType)
        Log.d(TAG, "setTaskInfo: $set")
        prefs?.edit()?.putStringSet(workId, set)?.apply();
    }

    fun getTaskInfo(workId: String): MutableSet<String>? {
        if (ContextHolder.getApplicationContext() == null) return null;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFERENCES_KEY, 0)
        val info = prefs?.getStringSet(workId, setOf())
        return if (info?.isEmpty() == true) null else info
    }


    fun getTaskId(workId: String): String? {
        if (ContextHolder.getApplicationContext() == null) return null;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFERENCES_KEY, 0)
        val taskId = prefs?.getString(workId, "null");
        Log.d(TAG, "getTaskId: Prefs Map : ${prefs?.all}")
        Log.d(TAG, "getTaskId: $taskId")
        return if (taskId == "null") null else taskId
    }

    fun getWorkId(taskId: String): String? {
        if (ContextHolder.getApplicationContext() == null) return null;
        val prefs =
            ContextHolder.getApplicationContext()?.getSharedPreferences(Constants.Strings.SHARED_PREFERENCES_KEY, 0)
        val values = prefs?.all?.entries

        val entry = values?.filter {
            it.value == taskId
        }
        return entry?.last()?.key
    }
}