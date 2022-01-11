package com.thecodedimension.background_task_manager

import android.content.Context
import android.util.Log

class ContextHolder {
    companion object {
        private var applicationContext: Context? = null

        fun getApplicationContext(): Context? {
            return applicationContext
        }

        fun setApplicationContext(applicationContext: Context?) {
            Log.d("FLTFireContextHolder", "received application context.")
            this.applicationContext = applicationContext
        }
    }

}