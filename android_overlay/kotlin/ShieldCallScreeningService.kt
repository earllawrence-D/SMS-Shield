package com.example.shieldsms

import android.telecom.Call
import android.telecom.CallScreeningService

class ShieldCallScreeningService : CallScreeningService() {
    override fun onScreenCall(details: Call.Details) {
        val b = CallResponse.Builder()
        if (details.callDirection == Call.Details.DIRECTION_INCOMING) {
            val num = details.handle?.schemeSpecificPart ?: ""
            val d = CallRules.decide(this, num, System.currentTimeMillis(), null)
            if (d.reject) b.setDisallowCall(true).setRejectCall(true)
        }
        respondToCall(details, b.build())
    }
}
