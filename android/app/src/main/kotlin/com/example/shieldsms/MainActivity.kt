package com.example.shieldsms

import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object { var channel: MethodChannel? = null }
    private var pending: MethodChannel.Result? = null

    private fun roleHeld(): Boolean {
        val rm = getSystemService(RoleManager::class.java)
        return rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) && rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    override fun configureFlutterEngine(fe: FlutterEngine) {
        super.configureFlutterEngine(fe)
        val ch = MethodChannel(fe.dartExecutor.binaryMessenger, "shieldsms/native")
        channel = ch
        ch.setMethodCallHandler { c, r ->
            val p = CallRules.prefs(this)
            when (c.method) {
                "drainSms" -> {
                    val messages = org.json.JSONArray()
                    val storedSms = mutableListOf<Triple<String, String, Long>>()
                    // First include already-stored inbox messages so existing SMS can be analyzed.
                    if (checkSelfPermission(android.Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED) {
                        contentResolver.query(Telephony.Sms.Inbox.CONTENT_URI,
                            arrayOf(Telephony.Sms._ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                            null, null, "${Telephony.Sms.DATE} ASC")?.use { cursor ->
                            val address = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                            val body = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
                            val date = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
                            while (cursor.moveToNext()) {
                                val from = cursor.getString(address) ?: "Unknown"
                                val text = cursor.getString(body) ?: ""
                                val time = cursor.getLong(date)
                                storedSms.add(Triple(from, text, time))
                                messages.put(JSONObject().put("from", from).put("text", text).put("t", time))
                            }
                        }
                    }
                    // Include new arrivals even when the SMS provider has not stored them yet.
                    val queued = org.json.JSONArray(p.getString("smsq", "[]"))
                    for (i in 0 until queued.length()) {
                        val item = queued.getJSONObject(i)
                        val from = item.optString("from", "Unknown")
                        val text = item.optString("text", "")
                        val time = item.optLong("t", 0L)
                        val alreadyStored = storedSms.any { it.first == from && it.second == text && kotlin.math.abs(it.third - time) < 120_000L }
                        if (!alreadyStored) messages.put(item)
                    }
                    p.edit().putString("smsq", "[]").apply()
                    r.success(messages.toString())
                }
                "getCalls" -> r.success(p.getString("calls", "[]"))
                "clearCalls" -> { p.edit().putString("calls", "[]").apply(); r.success(null) }
                "setRejectEnabled" -> { p.edit().putBoolean("rej", c.arguments as Boolean).apply(); r.success(null) }
                "hasCallScreeningRole" -> r.success(roleHeld())
                "evaluateCall" -> {
                    val d = CallRules.decide(this, c.argument<String>("num")!!, (c.argument<Number>("now")!!).toLong(), c.argument<Boolean>("saved"))
                    r.success(JSONObject().put("a", d.label).put("why", d.why).put("reject", d.reject).toString())
                }
                "requestCallScreeningRole" -> {
                    val rm = getSystemService(RoleManager::class.java)
                    if (rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) && !rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                        pending = r
                        startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING), 42)
                    } else r.success(null)
                }
                else -> r.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 42) { pending?.success(null); pending = null }
    }
}
