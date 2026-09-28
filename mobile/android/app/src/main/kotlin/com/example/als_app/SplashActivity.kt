package com.example.als_app

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.appcompat.app.AppCompatActivity

/**
 * Lightweight launcher trampoline. Its theme is translucent, so Android never
 * draws a cold-start splash screen / launcher icon for it. Instead it paints a
 * full-screen solid green view (matching the Flutter splash background), holds
 * it briefly, then hands off to [MainActivity] (the Flutter activity). The
 * result: a clean green screen with absolutely no icon, then the custom Flutter
 * splash appears.
 */
class SplashActivity : AppCompatActivity() {
    private var handedOff = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_splash)

        Handler(Looper.getMainLooper()).postDelayed({ goToMain() }, SPLASH_HOLD_MS)
    }

    private fun goToMain() {
        if (handedOff) return
        handedOff = true
        startActivity(Intent(this, MainActivity::class.java))
        finish()
        overridePendingTransition(0, 0)
    }

    companion object {
        private const val SPLASH_HOLD_MS = 500L
    }
}
