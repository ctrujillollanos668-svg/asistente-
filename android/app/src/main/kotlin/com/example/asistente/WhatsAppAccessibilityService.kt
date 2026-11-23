package com.example.asistente

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class WhatsAppAccessibilityService : AccessibilityService() {

    companion object {
        var isAutoSendScheduled: Boolean = false
        var instance: WhatsAppAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isAutoSendScheduled || event == null) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName != "com.whatsapp" && packageName != "com.whatsapp.w4b") return

        // Esperar brevemente (400ms) a que la interfaz de WhatsApp y el botón de enviar carguen
        Handler(Looper.getMainLooper()).postDelayed({
            if (isAutoSendScheduled) {
                attemptClickSendButton()
            }
        }, 400)
    }

    private fun attemptClickSendButton() {
        val rootNode = rootInActiveWindow ?: return
        try {
            // 1. Buscar por ID estándar de WhatsApp ('send')
            val sendById = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/send")
            if (!sendById.isNullOrEmpty()) {
                for (node in sendById) {
                    if (performClickRecursive(node)) {
                        isAutoSendScheduled = false
                        return
                    }
                }
            }

            // 2. Buscar por descripción de contenido ('Enviar', 'Send')
            val sendByDescEs = rootNode.findAccessibilityNodeInfosByText("Enviar")
            if (!sendByDescEs.isNullOrEmpty()) {
                for (node in sendByDescEs) {
                    if (performClickRecursive(node)) {
                        isAutoSendScheduled = false
                        return
                    }
                }
            }

            val sendByDescEn = rootNode.findAccessibilityNodeInfosByText("Send")
            if (!sendByDescEn.isNullOrEmpty()) {
                for (node in sendByDescEn) {
                    if (performClickRecursive(node)) {
                        isAutoSendScheduled = false
                        return
                    }
                }
            }

            // 3. Búsqueda profunda en la jerarquía de vistas
            searchAndClick(rootNode)
        } catch (_: Exception) {
        }
    }

    private fun searchAndClick(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""
        val viewId = node.viewIdResourceName?.lowercase() ?: ""

        if (viewId.contains("send") || desc.contains("enviar") || desc.contains("send") || text == "enviar" || text == "send") {
            if (performClickRecursive(node)) {
                isAutoSendScheduled = false
                return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (searchAndClick(child)) {
                return true
            }
        }
        return false
    }

    private fun performClickRecursive(node: AccessibilityNodeInfo?): Boolean {
        var current = node
        while (current != null) {
            if (current.isClickable) {
                return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            current = current.parent
        }
        return false
    }

    override fun onInterrupt() {
        isAutoSendScheduled = false
    }
}
