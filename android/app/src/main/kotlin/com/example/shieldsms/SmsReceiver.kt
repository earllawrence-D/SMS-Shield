package com.example.shieldsms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject

/** Queues incoming SMS (sender + content kept separate). Dart drains the queue and runs the fuzzy classifier. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val bySender = LinkedHashMap<String, StringBuilder>()
        for (m in parts) bySender.getOrPut(m.originatingAddress ?: "Unknown") { StringBuilder() }.append(m.messageBody ?: "")
        val p = CallRules.prefs(ctx)
        val q = JSONArray(p.getString("smsq", "[]"))
        for ((from, body) in bySender) q.put(JSONObject().put("from", from).put("text", body.toString()).put("t", System.currentTimeMillis()))
        p.edit().putString("smsq", q.toString()).apply()
        MainActivity.channel?.invokeMethod("smsArrived", null) // if the app is open, classify immediately
    }
}
