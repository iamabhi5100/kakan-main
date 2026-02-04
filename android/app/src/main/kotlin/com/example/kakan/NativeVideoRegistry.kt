package com.example.kakan

import java.util.concurrent.ConcurrentHashMap

/**
 * Registry of NativeVideoPlatformView instances by id for MethodChannel routing.
 */
internal object NativeVideoRegistry {
    private val views = ConcurrentHashMap<String, NativeVideoPlatformView>()

    fun register(id: String, view: NativeVideoPlatformView) {
        views[id] = view
    }

    fun unregister(id: String) {
        views.remove(id)
    }

    fun get(id: String): NativeVideoPlatformView? = views[id]
}
