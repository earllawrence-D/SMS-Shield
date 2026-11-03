package com.example.shieldsms

import android.app.role.RoleManager
import android.content.Intent
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
                "drainSms" -> { val s = p.getString("smsq", "[]"); p.edit().putString("smsq", "[]").apply(); r.success(s) }
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
