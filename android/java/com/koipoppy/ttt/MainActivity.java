package com.koipoppy.ttt;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.webkit.WebSettings;
import android.webkit.WebView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView webview = new WebView(this);
        WebSettings s = webview.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        webview.setOverScrollMode(View.OVER_SCROLL_NEVER);
        setContentView(webview);
        webview.loadUrl("file:///android_asset/index.html");
    }
}
