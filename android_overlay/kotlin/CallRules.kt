package com.example.shieldsms

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import org.json.JSONArray
import org.json.JSONObject

/** Fig 3.11 call-filtering rules. Independent of the fuzzy SMS score. Used by the real service and the in-app simulator. */
object CallRules {
    const val WINDOW = 20 * 60 * 1000L
    data class Decision(val reject: Boolean, val label: String, val why: String)

    fun prefs(c: Context) = c.getSharedPreferences("shieldsms", Context.MODE_PRIVATE)

    /** true/false = saved or not; null = cannot check (READ_CONTACTS missing). */
    private fun isSaved(c: Context, n: String): Boolean? {
        if (c.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return null
        val u = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(n))
        c.contentResolver.query(u, arrayOf(ContactsContract.PhoneLookup._ID), null, null, null)?.use { return it.count > 0 }
        return false
    }

    @Synchronized
    fun decide(c: Context, n: String, now: Long, forceSaved: Boolean?): Decision {
        val p = prefs(c)
        val log = JSONArray(p.getString("calls", "[]"))
        val rejectOn = p.getBoolean("rej", true)
        val saved = forceSaved ?: isSaved(c, n)
        val d: Decision = when {
            saved == null -> Decision(false, "Allowed", "READ_CONTACTS unavailable: cannot verify caller")
            saved -> Decision(false, "Allowed", "Saved contact")
            !rejectOn -> Decision(false, "Allowed", "Call rejection disabled")
            else -> {
                val prior = ArrayList<JSONObject>()
                for (i in 0 until log.length()) {
                    val o = log.getJSONObject(i)
                    if (o.getString("num") == n && o.getString("a") == "Rejected" && !o.optBoolean("used") && now - o.getLong("t") <= WINDOW) prior.add(o)
                }
                if (prior.size >= 3) { prior.forEach { it.put("used", true) }; Decision(false, "Allowed", "4th call: repeated-call exception") }
                else Decision(true, "Rejected", "Unknown caller (attempt ${prior.size + 1}/3)")
            }
        }
        log.put(JSONObject().put("num", n).put("a", d.label).put("why", d.why).put("t", now).put("used", false))
        p.edit().putString("calls", log.toString()).apply()
        return d
    }
}
