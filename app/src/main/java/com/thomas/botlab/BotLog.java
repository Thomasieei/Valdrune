package com.thomas.botlab;

import android.content.Context;
import java.io.File;
import java.io.FileWriter;
import java.io.RandomAccessFile;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Journal horodaté de toutes les décisions et actions du bot (pour le dossier envoyé au studio). */
public class BotLog {
    private static File file;
    private static final SimpleDateFormat FMT = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.FRANCE);

    public static synchronized void init(Context c) {
        if (file == null) file = new File(c.getApplicationContext().getFilesDir(), "bot_log.txt");
    }

    public static synchronized void log(String s) {
        if (file == null) return;
        try (FileWriter w = new FileWriter(file, true)) {
            w.write(FMT.format(new Date()) + "  " + s + "\n");
        } catch (Exception ignored) { }
    }

    /** Fin du journal (au plus ~300 Ko). */
    public static synchronized String read() {
        if (file == null || !file.exists()) return "(journal vide)";
        try (RandomAccessFile f = new RandomAccessFile(file, "r")) {
            long len = f.length(), max = 300_000;
            long start = Math.max(0, len - max);
            f.seek(start);
            byte[] b = new byte[(int) (len - start)];
            f.readFully(b);
            String s = new String(b, "UTF-8");
            if (start > 0) { int nl = s.indexOf('\n'); if (nl >= 0) s = "[… début tronqué …]\n" + s.substring(nl + 1); }
            return s;
        } catch (Exception e) { return "Erreur de lecture : " + e; }
    }

    public static synchronized long size() { return file == null || !file.exists() ? 0 : file.length(); }

    public static synchronized void clear() { if (file != null) file.delete(); }
}
