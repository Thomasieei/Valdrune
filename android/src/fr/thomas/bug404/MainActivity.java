package fr.thomas.bug404;

import android.app.Activity;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/** BUG 404 : le jeu HTML5 embarqué, servi depuis les assets de l'APK. */
public class MainActivity extends Activity {
    private static final String HOTE = "appassets.androidplatform.net";
    private WebView vue;

    @Override
    protected void onCreate(Bundle etat) {
        super.onCreate(etat);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (Build.VERSION.SDK_INT >= 28) {
            getWindow().getAttributes().layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }
        vue = new WebView(this);
        vue.setBackgroundColor(0xFF07060D);
        WebSettings s = vue.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        vue.setWebChromeClient(new WebChromeClient());
        vue.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (!HOTE.equals(u.getHost())) return null;
                String chemin = u.getPath();
                if (chemin == null || chemin.equals("/") || chemin.isEmpty()) chemin = "/index.html";
                Map<String, String> entetes = new HashMap<>();
                entetes.put("Access-Control-Allow-Origin", "*");
                entetes.put("Cache-Control", "no-cache");
                try {
                    InputStream in = getAssets().open("www" + chemin);
                    return new WebResourceResponse(typeMime(chemin), "utf-8", 200, "OK", entetes, in);
                } catch (IOException e) {
                    return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", entetes, null);
                }
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest req) {
                return !HOTE.equals(req.getUrl().getHost());
            }
        });
        setContentView(vue);
        pleinEcran();
        vue.loadUrl("https://" + HOTE + "/index.html");
    }

    private static String typeMime(String p) {
        String c = p.toLowerCase();
        if (c.endsWith(".html")) return "text/html";
        if (c.endsWith(".js") || c.endsWith(".mjs")) return "text/javascript";
        if (c.endsWith(".json")) return "application/json";
        if (c.endsWith(".txt")) return "text/plain";
        if (c.endsWith(".png")) return "image/png";
        if (c.endsWith(".ogg")) return "audio/ogg";
        if (c.endsWith(".css")) return "text/css";
        if (c.endsWith(".svg")) return "image/svg+xml";
        return "application/octet-stream";
    }

    @SuppressWarnings("deprecation")
    private void pleinEcran() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
    }

    @Override
    public void onWindowFocusChanged(boolean focus) { super.onWindowFocusChanged(focus); if (focus) pleinEcran(); }

    @Override
    protected void onPause() { super.onPause(); if (vue != null) vue.onPause(); }

    @Override
    protected void onResume() { super.onResume(); if (vue != null) vue.onResume(); pleinEcran(); }

    @Override
    public void onBackPressed() { moveTaskToBack(true); }
}
