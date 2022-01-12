package com.thecodedimension.background_task_manager

import android.util.Log
import io.flutter.plugin.common.EventChannel

class BtmStreamHandler : EventChannel.StreamHandler {
    private val TAG = "BtmStreamHandler"

    private var eventSink: EventChannel.EventSink? = null

    fun sendEvent(event: HashMap<String, String?>) {
        Log.d(TAG, "eventSink= $eventSink, sendEvent: $event")
        eventSink?.success(event)
    }

    fun dispose() {

    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel: args : $arguments")
        eventSink?.endOfStream()
        eventSink = null
    }
}