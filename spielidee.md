Game Specification: „Wachsen \& Verflechten“ (Arbeitstitel)

1\. Übersicht \& Philosophie

Genre: Gewaltfreies 2D-Logik- und Entspannungspuzzle.



Zielgruppe: Spieler, die eine entspannende, ästhetische und meditative Herausforderung suchen.



Grundprinzipien:



Keine physische Gewalt oder aggressive Thematik.



Keine Diskriminierung.



Keine Monetarisierung/Geldanreize (keine In-App-Käufe, keine Paywalls, keine Werbung, keine Lootboxen).



Einfache Regeln, die intuitiv zu lernen sind, aber tiefe Rätsel ermöglichen.



2\. Kern-Gameplay \& Spielmechanik

2.1 Das Spielfeld \& Raster

Struktur: Ein 2D-Gitterraster (z. B. 5x4, 6x6 Felder).



Feldtypen:



Startfelder \[S1], \[S2], ...: Ausgangspunkte für Ranken (verschiedenfarbige Knospen/Blumen).



Leere Felder \[ ]: Begehbare Flächen, die mit einer Ranke bedeckt werden müssen.



Blockade-Felder \[X]: Unpassierbare Steine/Hindernisse. Ranken dürfen diese Felder niemals betreten oder durchkreuzen.



Ziel-Knospe \[Z]: Zielpunkt, den eine Ranke erreichen muss, um das Level abzuschließen.



2.2 Regeln \& Zielbedingung

Abdeckung: Alle leeren Felder \[ ] auf dem Spielfeld müssen von Ranken bedeckt sein (100 % Begrünung).



Überschneidungsverbot: Ranken dürfen sich nicht kreuzen und nicht auf bereits bewachsene Felder zurückgewachsen werden.



Hindernisse: Steine \[X] versperren den Weg.



Gewinnbedingung: Wenn alle begehbaren Felder bedeckt sind UND die Ziel-Knospe \[Z] erreicht wurde, erblüht das Level.



3\. Steuerung \& Haptik (Game Feel)

3.1 Interaktion (Touch)

Primär: Drag \& Trace (Wischen/Ziehen). Der Spieler tippt auf eine Startknospe und zieht den Finger über das Raster. Die Ranke folgt Schritt für Schritt dem Fingerpfad.



Rückgängig: Ziehen auf dem gleichen Pfad zurück zieht die Ranke stufenlos/feldweise wieder ein.



Alternativ/Sekundär: Tap-to-Turn (Tippen zum Umlenken) für präzises Steuern auf kleinen Displays.



3.2 Feedback \& Juiciness

Visuell:



Wenn eine Ranke über ein Feld wächst, sprießen sanft Halme, Blätter und kleine Partikel.



Versucht der Spieler, auf einen Stein \[X] zu wischen, zittert die Rankenspitze leicht (Feedback für blockierten Weg).



Beim Gewinn erstrahlt das Spielfeld in einer Lichtwelle und alle Felder blühen voll auf.



Akustisch (Dynamic Audio):



Sanfter, meditativer Grundsoundtrack (Kalimba, Akustikgitarre, Synth-Pads).



Feldweises Wachstum erzeugt ansteigende, sanfte Plopp-/Blatt-Töne.



Blockaden erzeugen ein weiches, dumpfes Holz-Klopfen.



Levelabschluss erzeugt einen harmonischen Akkord (Windspiel / Gong).



Haptisch (Vibration):



Zartes Mikroticken bei jedem überquerten Feld.



Weicher Stoß bei Berührung von Steinen.



Dreistufige Erfolgsvibrations-Welle bei Level-Abschluss.



4\. UI / UX \& Menüführung (Die Weltkarte)

Konzept „Der Lebensbaum“:



Das Hauptmenü zeigt einen großen, organisch wachsenden Baum.



Äste / Zweige: Repräsentieren Kapitel/Welten (z. B. Frühlingswiese, Schattiger Wald).



Knospen: Repräsentieren einzelne Level.



Fortschritt:



Ungelöste Level sind kleine, geschlossene Knospen.



Gelöste Level erblühen dauerhaft am Baum.



Vollständig absolvierte Kapitel lassen den gesamten Ast bunt erstrahlen.



Nahtlose Übergänge:



Tippen auf ein Level zoomt stufenlos in das Spielfeld hinein (kein harter Ladebildschirm).



Menüs:



Einstellungen (Ton, Haptik, Reset) erscheinen als unaufdringliches Holzschild/Blatt-Overlay.



5\. Vorgehaltene / Geplante Ideen (Backlog für spätere Updates)

Folgende Ideen wurden im Zuge der ersten Konzepterstellung gesammelt, sind aber für den ersten Minimal Viable Product (MVP) noch zurückgestellt:



Wassertropfen-Mechanik:



Wassertropfen auf Feldern, die von einer Ranke eingesammelt werden müssen, bevor sie die Zielknospe betreten kann (oder um geschlossene Knospen aufzuwecken).



Sonder-Pflanzenarten:



Sonnenblume: Benötigt ein Feld mit Sonnenstrahl.



Wasserlilie: Kann nur auf Wasserfeldern wachsen.



Dornenbusch: Wächst schneller (2 Felder pro Schritt), blockiert aber nachfolgende Pfade.



Sonder-Felder \& Dynamik:



Tunnel / Wurzelgänge: Verbinden zwei entfernte Felder miteinander.



Dreh-Knoten: Leiten die Ranke beim Betreten im 90-Grad-Winkel um.



Schalter \& Tore: Das Begrünen von Feld A öffnet ein Tor auf Feld B.



Optionaler „Blütenrausch“-Modus (Time-Attack / Zen-Timer):



Ein separater Modus neben dem Hauptspiel, in dem man auf Zeit innerhalb von 60 Sekunden so viele Felder wie möglich begrünen muss.



Zug-Limits / Zusatzziele:



Optionale Sternen-Bewertung für das Lösen eines Levels in minimalen Zügen.




6\. Festgelegte Regeln \& Vorgaben für das MVP (Stand 27.10.2026)

6.1 Präzisierte Spielregeln

1. Jedes Level hat 1 bis n Startknospen \[S] und genau eine Ziel-Knospe \[Z].
2. Aus jeder Startknospe wächst genau eine Ranke. Jede Startknospe muss benutzt werden: Die Ranke muss mindestens ein Feld lang sein.
3. Ranken wachsen nur orthogonal (oben/unten/links/rechts), nicht diagonal. Sie dürfen keine Steine \[X], keine anderen Ranken und nicht sich selbst betreten.
4. Hebt der Spieler den Finger, pausiert die Ranke. Tippen auf die Rankenspitze setzt das Wachstum fort.
5. Zurückziehen auf dem eigenen Pfad zieht die Ranke feldweise wieder ein.
6. Die Ziel-Knospe ist ein Endpunkt: Eine Ranke, die sie erreicht, ist dort beendet und kann nicht hindurchwachsen.
7. Jede Ranke muss in der Ziel-Knospe enden. Die Ziel-Knospe nimmt mehrere Ranken auf, je eine pro Seite (oben, unten, links, rechts). Deshalb hat ein Level höchstens 4 Startknospen. (Geändert am 27.10.2026; vorher genügte eine Ranke. Später: farbgebundene Ziele und zwei Ziel-Knospen; das Level-Format ist darauf vorbereitet.)
8. Gewinnbedingung: Alle leeren Felder sind bedeckt UND jede Ranke endet in der Ziel-Knospe.

6.2 Steuerung

- Nur „Drag \& Trace“. „Tap-to-Turn“ entfällt im MVP komplett (Backlog).

6.3 Level-Design

- Ein Level braucht mindestens eine gültige Lösung; alternative Lösungen sind erlaubt und erwünscht.
- Jedes Level enthält seine gewollte Hauptlösung. Ein Prüfwerkzeug (Solver) validiert diese und meldet zur Information, ob weitere Lösungen existieren.
- Die Hauptlösung kann später für ein Tipp-System genutzt werden.
- Umfang MVP: 2 Kapitel à 15 handgebaute Level.

6.4 Technik \& Plattform

- Engine: Godot 4 (GDScript), Export als native Android-App (APK/AAB).
- Hochformat, Smartphones, ab Android 8 (API 26).
- Spielstand nur lokal auf dem Gerät. Keine Internetverbindung, kein Tracking, keine Werbe-SDKs.
- Sprache: zunächst Deutsch, Texte übersetzbar angelegt (Englisch später).
- Grafik zunächst prozedural/Platzhalter, Audio aus freien Quellen (CC0).
- Barrierefreiheit: Ranken zusätzlich zur Farbe mit Symbol/Muster unterscheidbar.
- Vertrieb: zunächst APK zum Sideloaden; Play Store wird später entschieden.
