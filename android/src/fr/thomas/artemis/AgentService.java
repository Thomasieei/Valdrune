package fr.thomas.artemis;

import android.accessibilityservice.AccessibilityService;
import android.view.accessibility.AccessibilityEvent;

/**
 * Service d'accessibilité : les « yeux et les mains » d'Artémis sur le téléphone
 * (repris du helper Artemis), plus la bulle flottante et l'agent embarqué.
 */
public class AgentService extends AccessibilityService {
    static volatile AgentService I;

    private volatile String pkg = "", activity = "";
    Overlay overlay;
    private volatile Agent agent;

    @Override protected void onServiceConnected() {
        super.onServiceConnected();
        I = this;
        overlay = new Overlay(this);
        overlay.showBubble();
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent e) {
        if (e == null || e.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return;
        CharSequence p = e.getPackageName();
        if (p == null || p.toString().equals(getPackageName())) return;
        pkg = p.toString();
        CharSequence c = e.getClassName();
        activity = c != null ? c.toString() : "";
    }

    @Override public void onInterrupt() {}

    @Override public void onDestroy() {
        stopAgent();
        if (overlay != null) overlay.remove();
        I = null;
        super.onDestroy();
    }

    public String getCurrentPackageName() { return pkg; }
    public String getCurrentActivityName() { return activity; }

    boolean running() { Agent a = agent; return a != null && !a.stopped(); }

    void start(String goal) {
        if (goal == null || goal.trim().isEmpty() || running()) return;
        Agent a = new Agent(this, overlay, goal.trim());
        agent = a;
        overlay.running(goal.trim());
        Thread t = new Thread(a, "artemis-agent");
        t.start();
    }

    void stopAgent() { Agent a = agent; if (a != null) a.stop(); }

    void answer(String s) { Agent a = agent; if (a != null) a.answer(s); }

    void done() { agent = null; }
}
