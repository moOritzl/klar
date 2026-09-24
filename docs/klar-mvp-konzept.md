# Klar — MVP-Konzept v3

**Arbeitstitel:** Klar (Namensprüfung DPMA/App Store ausstehend)
**Kategorie:** Konsum-Bewusstsein & Risikominimierung
**Plattform:** iOS (SwiftUI, local-first), deutscher Markt zuerst
**Altersfreigabe:** 18+
**Stand:** September 2026 — ersetzt v2 (Juli 2026)

---

## 1. Zusammenfassung der Änderungen gegenüber v2

v2 war für Menschen gebaut, die ihren Konsum senken wollen, und hat Self-Monitoring und Action Planning als Paar ins Zentrum gestellt. Im Selbsttest hat sich gezeigt, dass Wenn-Dann-Pläne und die Nachfrage „Hat der Plan geholfen?" für jemanden ohne Reduktionsziel wie eine Pflicht wirken, die niemand bestellt hat. v3 zieht daraus die Konsequenz:

1. **Neue Zielgruppe:** Menschen, die konsumieren und dabei die Kontrolle behalten wollen. Reduzieren bleibt möglich, ist aber nicht mehr das Versprechen.
2. **Action Planning fällt weg:** Wenn-Dann-Pläne, Plan-Vorlagen, Plan-Check-in und Plan-Erfolgsquote werden entfernt. Klar verzichtet damit auf den einzigen experimentellen Komponentennachweis auf App-Ebene (§ 2.3). Das ist eine bewusste Entscheidung und wird in § 2.5 als Grenze geführt.
3. **Neuer Kern-Loop, der Rückblick:** Am Morgen danach werden die erlebten Folgen erfasst (körperlich, emotional, Gesamturteil) und beim nächsten Mal zurückgespielt (§ 2.4, Modul C).
4. **Kontingente werden zu Grenzen:** Das Monatskontingent bleibt, wird aber als selbst gesetzte Grenze gerahmt, nicht als Reduktionsziel (Modul D).
5. **Neuer § 7 zu Kommunikation und Compliance**, Altersfreigabe 18+ statt 17+ (Apple hat 17+ 2025 abgeschafft).
6. **Der Weekly Review fällt weg**: Die Rückmeldung kommt laufend über die Muster; ein wöchentliches Vollbild wäre genau die Art Pflicht-Moment, die P9 ausschließt.

Unverändert aus v2 bleiben Behavior Substitution, Problem Solving (neu angebunden, Modul E), Risikoinhalte als Public-Health-Funktion und der Ausschluss normativen Feedbacks.

---

## 2. Wissenschaftlicher Hintergrund

### 2.1 Reine Dokumentation verändert Konsum kaum („Measurement Reactivity")

Die Frage, ob das bloße Protokollieren von Konsum das Verhalten verändert, ist in der Forschung zu Ecological Momentary Assessment (EMA) gut untersucht — mit ernüchterndem Ergebnis. Shiffman (2009) resümiert in seinem Überblick zur EMA-Methodik bei Substanzkonsum, dass Studien bislang keine starken Reaktivitätseffekte gezeigt haben; selbst bei Rauchern unmittelbar vor einem Aufhörversuch — einer Population, in der Reaktivität maximal sein sollte — fand sich nur eine Reduktion von etwa 0,3 Zigaretten pro Tag ohne Veränderung biochemischer Marker. Für Problemtrinker berichten Hufford, Shields, Shiffman, Paty und Balabanis (2002) ebenfalls keine belastbare Reaktivität des Selbstmonitorings.

Das methodisch sauberste Experiment hierzu stammt von Buu et al. (2020): 307 Teilnehmende wurden randomisiert täglichen oder wöchentlichen Tagebuch-Erhebungen zugeteilt. Ergebnis: kurzfristige Reaktivität beim Alkoholkonsum, **keine** messbare Reaktivität beim Cannabiskonsum. Die Autor:innen führen das Ausbleiben nachhaltiger Effekte explizit darauf zurück, dass **kein Feedback** (z. B. grafische Aufbereitung der Verhaltensmuster) bereitgestellt wurde.

> **Produktkonsequenz:** Das Tagebuch ist Input, nicht Wirkmechanismus. Ein Logging-Feature ohne Feedback-Schicht ist verhaltenswissenschaftlich wertlos.

### 2.2 Digitale Interventionen wirken — aber moderat

Meta-analytisch ist die Wirksamkeit digitaler Selbsthilfe zur Konsumreduktion (Alkohol) gut belegt, die Effektstärken sind jedoch bescheiden. Riper et al. (2011) finden über neun RCTs zu internetbasierter Selbsthilfe ohne Therapeutenkontakt einen mittleren Gesamteffekt von g = 0,44. Donoghue, Patton, Phillips, Deluca und Drummond (2014) bestätigen die Wirksamkeit elektronischer Kurzinterventionen (eSBI), zeigen aber, dass die Effekte über die Zeit abnehmen. Der Cochrane-Review von Kaner et al. (2017) kommt für personalisierte digitale Interventionen zu einem ähnlichen Bild: wirksam, aber mit Effektgrößen im Bereich weniger Standardgetränke pro Woche.

Die bislang größte App-Einzelevaluation ist der Drink-Less-RCT (Oldham et al., 2024; n = 5.602): Die konservative Intention-to-treat-Analyse ergab eine statistisch nicht signifikante Mehrreduktion von 0,98 UK-Einheiten/Woche gegenüber der NHS-Webseite; die präregistrierte Sensitivitätsanalyse mit multipler Imputation zeigte eine signifikante Mehrreduktion von 2,00 Einheiten/Woche. Zur Einordnung: Beide Gruppen reduzierten im Studienverlauf um rund 37–39 Einheiten pro Woche — der App-spezifische Zusatzeffekt ist real, aber klein relativ zur Eigenmotivation der Nutzer:innen.

> **Produktkonsequenz:** Realistische Erwartungshaltung. Eine App verstärkt eine vorhandene Absicht, sie ersetzt sie nicht. Für Klar heißt das: Die App unterstützt Menschen, die ihren Konsum im Blick behalten *wollen*. Sie ist kein Ersatz für Motivation und keine Behandlung, und genau so wird sie kommuniziert (intern, im Store, gegenüber App Review). Die zitierten Studien haben allerdings Menschen mit Reduktionsziel untersucht (§ 2.5).

### 2.3 Welche Komponenten wirken: die Evidenz zu Behavior Change Techniques (BCTs)

Die Interventionsforschung zerlegt Programme in standardisierte Einzeltechniken (BCT-Taxonomie v1; Michie et al., 2013). Für digitale Alkohol-Interventionen zeigen zwei zentrale Synthesen ein konsistentes Muster:

- Die Meta-Regression von Garnett et al. (2018) über 41 digitale Interventionen findet **„Behavior Substitution", „Problem Solving" und „Credible Source"** mit stärkerer Konsumreduktion assoziiert. „Self-Monitoring" (in nur 29 % der Studien eingesetzt) und „Goal Setting" (43 %) gelten als wirksam, aber auffallend selten implementiert.
- Kaner et al. (2017) identifizieren **Goal Setting, Problem Solving, Information about Antecedents und Behavior Substitution** als signifikant mit reduziertem Konsum assoziierte Techniken.
- Black, Mullan und Sharpe (2016) finden in ihrer Meta-Regression über 93 computerbasierte Interventionen größere Effekte bei Commitment/Zielüberprüfung und normativem Feedback — aber **kleinere Effekte, wenn Informationen über die Konsequenzen des Konsums vermittelt wurden**.

Die präziseste Komponentenevidenz auf App-Ebene liefert der 2⁵-faktorielle RCT zur Drink-Less-App (Crane, Garnett, Michie, West & Brown, 2018; n = 672), in dem fünf Module einzeln in „enhanced"- vs. Minimalversion getestet wurden. Ergebnis: **keine signifikanten Haupteffekte einzelner Module** — aber eine signifikante Interaktion zwischen **Self-Monitoring & Feedback und Action Planning** auf den AUDIT-Score. Zugleich wurde das Self-Monitoring-Modul signifikant häufiger genutzt und deutlich besser bewertet (Hilfreichkeit, Zufriedenheit, Weiterempfehlung) als alle anderen Module.

Action Planning selbst ist gut fundiert. Es operationalisiert *Implementation Intentions* (Gollwitzer, 1999), also konkrete Wenn-Dann-Pläne, deren Effekt auf die Zielerreichung meta-analytisch mittel bis groß ist (d = 0,65 über 94 Studien; Gollwitzer & Sheeran, 2006).

> **Produktkonsequenz (v3):** v2 hat aus dem Crane-Befund das Kernargument gemacht: Self-Monitoring ist der Retention-Motor, Wirkung entsteht erst mit Action Planning. v3 verzichtet trotzdem auf Action Planning. Das Argument dagegen ist nicht schwache Evidenz, sondern die fehlende Passung zur Zielgruppe. Ein Wenn-Dann-Plan setzt ein Ziel voraus, das der Plan absichern soll. Wer den eigenen Konsum im Blick behalten, aber nicht senken will, hat dieses Ziel nicht, und der Plan wird zur Aufgabe ohne Anlass. Dass in der Drink-Less-Studie das Self-Monitoring deutlich mehr genutzt und besser bewertet wurde als die übrigen Module, passt dazu. Ein Beleg dafür, dass Action Planning verzichtbar ist, ist es nicht. Übrig bleibt das Prinzip aus § 2.1: Erfassung braucht Rückmeldung. v3 erweitert, *was* erfasst und zurückgespielt wird (§ 2.4).

### 2.4 Warum der Rückblick: erlebte Folgen beobachten

Die BCT-Taxonomie unterscheidet die Beobachtung des eigenen Verhaltens (2.3 *Self-monitoring of behaviour*) von der Beobachtung seiner Folgen (2.4 *Self-monitoring of outcome(s) of behaviour*; 5.4 *Monitoring of emotional consequences*) und kennt dazu die Rückmeldung über Folgen (2.7 *Feedback on outcome(s) of behaviour*; Michie et al., 2013). v2 hat nur das Verhalten erfasst: was, wann, wie viel, in welchem Kontext. Der Rückblick erfasst zusätzlich, wie es danach war. Er fragt nach dem körperlichen Zustand (Kater, Erschöpfung), nach Reue und nach einem Gesamturteil („Würdest du es wieder so machen?").

**Warum das wirken kann: Anticipated Regret.** Die Erwartung, eine Handlung später zu bereuen (BCT 5.5 *Anticipated regret*), sagt Absicht und Verhalten über die klassischen Prädiktoren der Theorie des geplanten Verhaltens hinaus vorher. Die Meta-Analyse von Sandberg und Conner (2008) findet einen starken Zusammenhang mit der Absicht (r = 0,47; k = 25; N = 11.254) und einen moderaten mit dem späteren Verhalten (r = 0,28; k = 8; N = 2.035). Der Rückblick gibt dieser Erwartung eine Datengrundlage: Statt zu raten, ob man es bereuen wird, sieht man, wie oft man es in ähnlichen Situationen bereut hat. Einschränkung: Die Befunde sind korrelativ und stammen nicht aus Interventionsstudien.

**Warum Erfassen allein nicht reicht.** Epler et al. (2014) haben 386 häufig trinkende Erwachsene 21 Tage lang per elektronischem Tagebuch begleitet (2.276 Trinkepisoden, davon 463 mit berichtetem Kater). Allein betrachtet verlängerte ein Kater die Zeit bis zum nächsten Drink im Median um etwa sechs Stunden. Im multivariaten Modell blieb der Effekt nur in Wechselwirkung mit Craving und finanziellen Stressoren bestehen, und ein morgens berichteter Kater hing nicht mit der eingeschätzten Wahrscheinlichkeit zusammen, am selben Tag wieder zu trinken. Die Autor:innen schließen auf einen allenfalls bescheidenen oder inkonsistenten Einfluss. Die erlebte Folge verblasst also, bevor die nächste Entscheidung fällt. Das ist dieselbe Lehre wie in § 2.1: Der Wert entsteht erst durch das Zurückspielen.

**Abgrenzung zu Black et al. (2016).** Dort waren *Informationen über Konsumfolgen* (BCT 5.1 *Information about health consequences*) mit kleineren Effekten assoziiert, also allgemeine Aufklärung von außen. Der Rückblick vermittelt keine Informationen, sondern hält die eigenen, erlebten Folgen fest. Das ist eine andere Technik. Der Befund von Black et al. lässt sich darauf nicht übertragen, er belegt aber auch nicht das Gegenteil.

**Bewusst ausgeschlossen: Pro-Contra-Abwägung.** Naheliegend wäre, nach Vor- und Nachteilen des Abends zu fragen (BCT 9.2 *Pros and cons*, im Motivational Interviewing als „Decisional Balance" bekannt). Miller und Rose (2015) zeigen in ihrer Übersicht, dass diese Abwägung bei ambivalenten Menschen die Bereitschaft zur Veränderung eher senkt, weil sie auch die Argumente für den Status quo stärkt. Klars Zielgruppe hat per Definition keinen Veränderungsentschluss. Der Rückblick fragt deshalb nach Folgen und einem einzelnen Gesamturteil, nie nach den Vorteilen des Konsums.

> **Produktkonsequenz:** Der Rückblick ist Input, das Zurückspielen ist der Mechanismus. Folgen werden am Morgen danach erfasst und dort wieder gezeigt, wo die App dem nächsten Konsum am nächsten ist: in der Übersicht und im Eintrag-Sheet. Das geschieht pro Substanz und Kontext und immer am eigenen Verlauf. Den eigentlichen Entscheidungsmoment kennt die App nicht; sie sieht nur, wann sie geöffnet wird.

### 2.5 Grenzen der Evidenz

Vier Einschränkungen sind für dieses Projekt konstitutiv und werden nicht wegdiskutiert:

1. **Substanz-Übertragbarkeit:** Nahezu die gesamte zitierte Evidenz stammt aus der Alkohol- und Tabakforschung. Für MDMA, Kokain, Ketamin u. a. existieren keine RCTs zu App-basierter Konsumreduktion. Die Kernannahme von Klar ist eine plausible Extrapolation, kein belegter Sachverhalt.
2. **Selbstselektion und Zielgruppe:** Alle Interventionsstudien rekrutierten reduktionsmotivierte Teilnehmende. Seit v3 liegt Klars Zielgruppe ausdrücklich außerhalb dieser Populationen. Über Effekte bei Menschen, die ihren Konsum im Blick behalten, aber nicht senken wollen, sagt die Evidenz nichts.
3. **Effektgrößen:** Auch im besten Fall sind die Zusatzeffekte digitaler Interventionen klein (§ 2.2). Marketing- und Store-Kommunikation dürfen keine Wirkversprechen enthalten — auch aus Compliance-Gründen (keine Health Claims, keine Medical-Positionierung; § 7).
4. **Rückblick ohne App-Evidenz:** Für Outcome-Monitoring mit Zurückspielen gibt es keinen Komponententest auf App-Ebene, der mit Crane et al. (2018) vergleichbar wäre. Die Begründung stützt sich auf die BCT-Taxonomie, auf korrelative Befunde (Sandberg & Conner, 2008) und auf eine EMA-Studie, die zeigt, was ohne Zurückspielen passiert (Epler et al., 2014). Diese Grundlage ist schwächer als die von v2, und so wird sie auch kommuniziert.

---

## 3. Ableitung: Designprinzipien für das MVP

| # | Prinzip | Evidenzbasis |
|---|---|---|
| P1 | Logging ist Input, nie Selbstzweck; jede Erfassung mündet in Feedback | Buu et al. (2020); Shiffman (2009) |
| P2 | Konsum und erlebte Folgen werden als Paar erfasst und zurückgespielt | BCT 2.3, 2.4, 2.7, 5.4 (Michie et al., 2013); Epler et al. (2014) |
| P3 | Behavior Substitution und Problem Solving als leichtgewichtige Begleitmodule | Garnett et al. (2018); Kaner et al. (2017) |
| P4 | Kein normatives Feedback | keine validen Normdaten für illegale Substanzen; Backfire-Risiko („ich liege ja unterm Schnitt"); der positive Befund bei Black et al. (2016) bezieht sich auf Alkohol mit belastbaren Referenzwerten |
| P5 | Risikoinhalte sind Notfall- und Public-Health-Funktion, kein Reduktionsversprechen. Das gilt für allgemeine Aufklärung über Konsumfolgen (BCT 5.1), nicht für die eigenen, im Rückblick erfassten Folgen (P2) | Black et al. (2016): Konsequenz-Aufklärung ist mit kleineren Effekten assoziiert |
| P6 | Inhalte kommen von etablierten Organisationen und werden attribuiert („Credible Source") | Garnett et al. (2018) |
| P7 | Feedback bleibt neutral und am eigenen Baseline-Verlauf orientiert — kein Lob für Konsum, keine Moralisierung | Positionierungsentscheidung v1; konsistent mit P4 |
| P8 | Der Rückblick fragt nach Folgen und einem Gesamturteil, nie nach der Qualität des Rauschs und nie nach Vorteilen des Konsums | App Store Review Guideline 1.4.3 (§ 7); Miller & Rose (2015) |
| P9 | Keine Pflicht-Interaktion: Jede Nachfrage ist mit einem Tap überspringbar, wird nicht wiederholt und löst keine Push-Mitteilung aus | Produkterfahrung aus v2 (Plan-Check-in als Belastung); kein Studienbefund |

---

## 4. MVP-Featureset v3

### Modul A — Erfassung (Self-Monitoring)
- 2-Tap-Logging: „+" → Substanz → gespeichert; Zeitstempel automatisch, editierbar
- Dosisfeld (mg/g/ml, selbstberichtet), Kontext-Tags (allein/sozial/Club/zuhause), überspringbar
- Vorbefüllte Substanzliste, persönliche Auswahl im Onboarding, eigene Einträge möglich
- Kalenderansicht: eintragsfreie Tage als visuell positiver Grundzustand

### Modul B — Feedback
- Trends pro Substanz: Frequenz, Ø-Dosis über Zeit, Lücken
- Rückblick-Muster pro Substanz und Kontext-Tag (Modul C) in der Übersicht und im Eintrag-Sheet, als Zählung ohne Score
- Referenzpunkt ist ausschließlich die eigene Baseline (P7)

### Modul C — Rückblick (neu, ersetzt Action Planning)
- **Auslöser:** Wenn ein logischer Tag mit mindestens einem Eintrag endet (Grenze 05:00, `LogicalDay`), zeigt die App beim nächsten Öffnen eine Karte. Es gibt keine Push-Mitteilung (P9).
- **Eine Karte pro Konsumtag**, nicht pro Eintrag. Die Antworten gelten für alle Substanzen und Kontext-Tags dieses Tages.
- **Drei Fragen**, jede mit einem Tap auf einer neutralen Drei-Stufen-Skala beantwortbar, jede einzeln und die ganze Karte überspringbar:
  1. „Wie geht's dir heute körperlich?" — gut / etwas angeschlagen / richtig verkatert
  2. „Bereust du etwas von gestern?" — nein / ein bisschen / ja
  3. „Würdest du es wieder so machen?" — ja / anders / nein
- Optionale Freitext-Notiz.
- **Verfall:** Fällig ist nur der jüngste Konsumtag vor heute. Er verfällt 48 Stunden nach seinem Ende (05:00 am Folgetag). Ein neuer Konsumtag verdrängt einen älteren, unbeantworteten; ein Eintrag am selben Morgen tut das nicht.
- **Pro Substanz schaltbar** („Morgen danach fragen" im Tab Grenzen), bei Nikotin standardmäßig aus.
- **Zurückspielen:** Ab drei beantworteten Rückblicken für eine Substanz zeigt die Übersicht eine Zeile wie „Letzte 5×: 3× verkatert, 1× bereut". Im Eintrag-Sheet erscheint dieselbe Zählung für die gewählte Kombination aus Substanz und Kontext-Tag, sobald dafür drei Rückblicke vorliegen. Die Anzeige besteht aus Zahlen, ohne Score, Farbwertung oder Kommentar (P7).
- **Ausgeschlossen:** Bewertung des Rauschs, „bester Abend", Serien positiver Antworten, Vor-/Nachteil-Listen (P8).
- **Entfernt aus v2:** Wenn-Dann-Pläne, Plan-Vorlagen, Plan-Check-in, Plan-Erfolgsquote.

### Modul D — Grenzen (war: Ziele & Reduktion)
- Pro Substanz eine selbst gesetzte Monatsgrenze („max. N×"); 0 ist als Sonderfall möglich
- Die Anzeige zählt hoch und zählt über die Grenze hinaus weiter: „3 von max. 4", „5 von max. 4" (`KlarCore.QuotaReading`). Ein Überschreiten wird angezeigt, nicht bewertet.
- Rahmung: eine Grenze, die man sich selbst setzt, um die Kontrolle zu behalten, kein Reduktionsziel
- Eintragsfreie Serien, Ausgaben pro Monat (nutzerdefinierte Kostenbasis; ersetzt „Geld gespart", das ein Reduktionsziel voraussetzt)

### Modul E — Craving-SOS (mit Behavior Substitution & Problem Solving)
- Urge-Surfing-Timer, Atemübung, eigene „Warum"-Notizen, Ein-Tap-Anruf an selbstgewählten Kontakt
- **Behavior Substitution:** Nutzer:in hinterlegt im Onboarding 2–3 Ersatzhandlungen („rausgehen", „Freund:in schreiben", „duschen"); SOS-Screen schlägt genau diese vor
- **Problem Solving:** Nach einem Rückblick mit „bereut: ja" gibt es einen optionalen 3-Fragen-Flow (Was war der Auslöser? Was hätte geholfen? Was machst du nächstes Mal anders?) — ein Eintrag, der eine Grenze überschreitet, löst ihn nicht eigens aus, dieser Tag bekommt ohnehin am nächsten Morgen eine Karte. Die letzte Antwort wird als Notiz gespeichert und beim nächsten Zurückspielen für diese Substanz und diesen Kontext mit angezeigt. Es entsteht kein Plan, und es gibt keine Nachfrage, ob es geklappt hat.

### Modul F — Notfall & Beratung (Public-Health-Schicht)
- Notfall-Screen: Warnzeichen erkennen, Erste-Hilfe-Schritte, Ein-Tap-112
- Suchtberatungs-Verzeichnis (DE, statisch in v1), Sucht & Drogen Hotline
- Risikohinweise pro Substanz im Starter-Set (5–8 Substanzen): ausschließlich Gefahrenvermeidung, gefährliche Kombinationen, Notfallsymptome; Quellen attribuiert (BZgA/drugcom.de, mindzone, Saferparty) — **keine Dosisempfehlungen, keine Wirkoptimierung** (vgl. Produktverfassung v1, § 5)

### Modul G — Privatsphäre
- Local-first, kein Account, kein Server; Face-ID-Sperre; Panik-Verbergen; vollständiger Export (JSON/CSV) und echte Löschung
- Optionaler iCloud-Sync (privater CloudKit-Container) nach MVP

### Explizit nicht im MVP
Widgets, EN-Lokalisierung, Drug-Checking-Alerts (Lizenzierung), Forschungs-Datenspende (erst mit akademischem Partner und Ethikvotum, siehe Diskussionsstand), Apple-Health-Integration, Wenn-Dann-Pläne (entfernt in v3, § 1). **Dauerhaft ausgeschlossen** bleiben alle Punkte der Produktverfassung (v1, § 5): Dosisempfehlungen, „How-to"-Inhalte, soziale Feeds, Beschaffungshilfen, normatives Feedback (§ 3, P4). Neu dazu kommt jede Bewertung der Rauschqualität (P8).

---

## 5. Validierung

Unverändert zu v1 bleibt die Retention: ≥ 50 % loggen noch in Woche 4, bei ≥ 20 Testnutzer:innen über 4+ Wochen. Die Plan-Metrik aus v2 entfällt. An ihre Stelle tritt der Rückblick:

- **Antwortquote:** Anteil der Konsumtage in Woche 4, deren Rückblick mindestens teilweise beantwortet wurde. Arbeitsziel ≥ 50 %, ohne externe Referenz gesetzt.
- **Reichweite des Zurückspielens:** Anteil der Nutzer:innen, denen bis Woche 4 mindestens ein Rückblick-Muster angezeigt wurde.
- **Belastung (qualitativ):** Im Abschlussinterview die Frage, ob die Karte am Morgen als nützlich oder als Pflicht erlebt wurde. Das ist der Punkt, an dem der Plan-Check-in in v2 gescheitert ist.

Begründung: Wenn das Zurückspielen erlebter Folgen der Mechanismus ist (§ 2.4), sind Antwortquote und Reichweite die frühesten Indikatoren dafür, dass Klar mehr ist als ein Tagebuch. Eine sinkende Antwortquote bei stabiler Logging-Retention wäre das Zeichen, dass der Rückblick dieselbe Last erzeugt wie vorher die Pläne.

---

## 6. Limitationen dieses Dokuments

Dieses Konzept überträgt Evidenz aus der Alkohol-/Tabakforschung auf illegale Substanzen und aus reduktionsmotivierten Studienpopulationen auf eine Zielgruppe ohne Reduktionsziel (§ 2.5). Es ist kein medizinisches Produkt, keine Behandlung und erhebt keinen therapeutischen Anspruch. Die zitierten Effektgrößen beziehen sich auf andere Substanzen, andere Populationen und teils andere Interventionsformate; sie begründen Designentscheidungen, keine Wirkversprechen. Eine Evaluation im eigenen Anwendungskontext (perspektivisch mit akademischem Partner) ist der einzige Weg, diese Lücke zu schließen.

---

## 7. Kommunikation & Compliance

Dieser Abschnitt ist eine Arbeitsgrundlage, keine Rechtsberatung. Vor dem Launch lassen wir ihn prüfen.

**App Store Review Guideline 1.4.3.** Apple lässt keine Apps zu, die zum Konsum von Tabak- und Vape-Produkten, illegalen Drogen oder übermäßigem Alkohol *ermutigen*. Reflexion über Konsum fällt nicht darunter. Riskant wäre alles, was Konsum positiv verstärkt. Daraus folgt:
- P8 gilt: Es gibt keine Bewertung des Rauschs, keine Rangliste von Abenden und keine Serien positiver Antworten.
- Positive Rückblick-Antworten werden nicht gefeiert, negative nicht getadelt (P7).
- In Store-Texten und Screenshots taucht kein Vokabular des Genusses auf („genießen", „das Beste rausholen").

**Guideline 1.4.1 (medizinische Apps).** Klar macht keine medizinischen Aussagen, stellt keine Diagnosen und gibt keine Dosisempfehlungen (Modul F).

**Altersfreigabe.** Apple hat im Juli 2025 die Stufen 13+, 16+ und 18+ eingeführt und 12+ und 17+ gestrichen. Der Fragebogen enthält seitdem auch Fragen zu medizinischen und Wellness-Inhalten. Klar wird mit 18+ eingereicht.

**EU-Medizinprodukteverordnung (MDR).** Software ist ein Medizinprodukt, wenn sie laut Hersteller einem medizinischen Zweck dient, u. a. der Verhütung, Überwachung oder Behandlung von Krankheiten (Art. 2 Nr. 1 MDR). Maßgeblich ist, was wir versprechen. Deshalb gilt für alle öffentlichen Texte:

| Verwenden | Vermeiden |
|---|---|
| im Blick behalten, sehen, verstehen | schützt vor Sucht, beugt Abhängigkeit vor |
| bewusst konsumieren | hilft bei Suchtproblemen, therapeutisch |
| selbst gesetzte Grenze | Behandlung, klinisch belegt, nachweislich wirksam |

„Die Kontrolle behalten" ist als interne Beschreibung der Zielgruppe in Ordnung. In Store- und Marketingtexten wird es sparsam eingesetzt, denn „Kontrollverlust" ist ein Diagnosekriterium der Abhängigkeit, und die Formulierung „nie die Kontrolle verlieren" liest sich schnell als Präventionsversprechen.

---

## Anhang A — Vorbereitete Texte für README und Landingpage

Diese Texte werden eingesetzt, **sobald Modul C gebaut und die Pläne aus der App entfernt sind**. Vorher würden README und Landingpage etwas beschreiben, das der Code nicht kann. Zahlen und Zitate entsprechen dem Literaturverzeichnis unten.

### A.1 README (Englisch)

**Erster Absatz** (ersetzt „An iOS app for people who want to cut down on their substance use without quitting."):

> An iOS app for keeping an honest eye on your own substance use, without having to quit.

**„Why this is not a tracker"** (ersetzt den Abschnitt vollständig):

> Logging on its own barely moves anything. Across the ecological momentary assessment literature (Shiffman, 2009) and a randomised diary experiment (Buu et al., 2020), self-monitoring produced little to no lasting change, and the authors of the latter put that down to the missing feedback.
>
> So Klar records a second thing. The morning after a day with entries, one skippable card asks how you feel, whether you regret anything, and whether you would do it the same way again. When you open the app later, it shows what those mornings looked like for the same substance and context: "Last 5 times: 3 hungover, 1 regretted."
>
> Recording the consequence is not enough either. In a diary study of 386 frequent drinkers, a hangover pushed the next drink back by a median of about six hours and had no consistent effect beyond that (Epler et al., 2014). The card is input. The point is to show the answers again later. This is also where the evidence gets thinner: anticipated regret predicts intentions and behaviour in correlational studies (Sandberg & Conner, 2008), but no trial has tested this loop inside an app.
>
> Two things are left out on purpose. The card never asks what was good about using, because getting ambivalent people to list the upsides of the status quo tends to weaken change (Miller & Rose, 2015). And there is no normative feedback ("you drink less than 70% of users"): no valid norm data exists for illegal substances, and a user below the average reads it as permission.
>
> Earlier versions paired logging with if-then plans, the one combination with component-level app evidence (Crane et al., 2018). Klar dropped them. For someone who wants to stay in control rather than cut down, a plan is a chore without a reason. The concept document spells out what that costs.

**„What it does"** (ersetzt den Absatz):

> Entry logging with context tags, a morning-after check-in, per-substance monthly limits that count up, a three-step weekly review, calendar and trend history, behaviour substitution prompts, and a craving SOS screen with attributed content from established organisations.

**„Limitations"**, neuer zweiter Satz nach dem ersten:

> The target group, people who want to stay in control rather than cut down, sits outside every study population cited.

Außerdem müssen Titelbild und Alt-Text neu gemacht werden, weil beide heute den aktiven Plan zeigen und beschreiben. Dasselbe gilt für `01-checkin.png` und die Plan-Zeile in `docs/screenshots/README.md`.

### A.2 Landingpage (`web/index.html`, DE/EN)

Die Hero-Zeile „Ehrlich mitschreiben, ohne aufhören zu müssen." bleibt, ebenso der `<title>`.

| Stelle | Deutsch | Englisch |
|---|---|---|
| Unterzeile | Konsum sehen, verstehen, im Blick behalten. Alles bleibt auf dem Gerät. | See your use, understand it, keep an eye on it. Everything stays on the device. |
| `meta description` und `og:description` | Klar ist eine iOS-App, mit der du deinen Konsum siehst, verstehst und im Blick behältst. Kein Konto, kein Server: alles bleibt auf dem Gerät. | (nur DE, wie bisher) |
| Abschnittstitel (statt „Ein Vorsatz muss da stehen, wo er gebraucht wird.") | Wie ein Abend war, merkst du am Morgen danach. | You find out how a night went the morning after. |
| Feature-Titel (statt „Wenn-Dann-Pläne") | Rückblick | Morning after |
| Feature-Text | Wie geht's dir, bereust du was, würdest du es wieder so machen? Drei Taps, jederzeit überspringbar. | How do you feel, any regrets, would you do it again? Three taps, always skippable. |
| Feature-Zusatz (statt „Höchstens drei gleichzeitig.") | Beim nächsten Mal steht da, wie die letzten Male ausgegangen sind. | Next time, it shows how the last few turned out. |
| Befund 2 (statt „Vorsätze wirken, wenn sie an eine Situation gebunden sind.") | Ein Kater allein hält kaum vom nächsten Mal ab. | A hangover on its own barely delays the next time. |
| Folgerung 2 (statt „Also sind Wenn-Dann-Pläne Kernfunktion, nicht Zusatz.") | Also holt Klar die Morgen danach zurück auf den Bildschirm. | So Klar puts those mornings back on screen. |
| Grenz-Hinweis | Ehrlich zur Grenze: Die Evidenz stammt vor allem aus Alkohol- und Tabakstudien mit Menschen, die weniger konsumieren wollten. Die Übertragung auf andere Substanzen und auf dich ist eine Annahme, die Klar prüft, kein Versprechen. | Honest about the limit: the evidence comes mostly from alcohol and tobacco studies of people who wanted to cut down. Transfer to other substances, and to you, is a hypothesis Klar tests, not a promise it markets. |

---

## Literaturverzeichnis

Black, N., Mullan, B., & Sharpe, L. (2016). Computer-delivered interventions for reducing alcohol consumption: Meta-analysis and meta-regression using behaviour change techniques and theory. *Health Psychology Review, 10*(3), 341–357. https://doi.org/10.1080/17437199.2016.1168268

Buu, A., Yang, S., Li, R., Zimmerman, M. A., Cunningham, R. M., & Walton, M. A. (2020). Examining measurement reactivity in daily diary data on substance use: Results from a randomized experiment. *Addictive Behaviors, 102*, 106198. https://doi.org/10.1016/j.addbeh.2019.106198

Crane, D., Garnett, C., Michie, S., West, R., & Brown, J. (2018). A smartphone app to reduce excessive alcohol consumption: Identifying the effectiveness of intervention components in a factorial randomised control trial. *Scientific Reports, 8*, 4384. https://doi.org/10.1038/s41598-018-22420-8

Donoghue, K., Patton, R., Phillips, T., Deluca, P., & Drummond, C. (2014). The effectiveness of electronic screening and brief intervention for reducing levels of alcohol consumption: A systematic review and meta-analysis. *Journal of Medical Internet Research, 16*(6), e142. https://doi.org/10.2196/jmir.3193

Epler, A. J., Tomko, R. L., Piasecki, T. M., Wood, P. K., Sher, K. J., Shiffman, S., & Heath, A. C. (2014). Does hangover influence the time to next drink? An investigation using ecological momentary assessment. *Alcoholism: Clinical and Experimental Research, 38*(5), 1461–1469. https://doi.org/10.1111/acer.12386

Garnett, C., Crane, D., Brown, J., et al. (2018). Behavior change techniques used in digital behavior change interventions to reduce excessive alcohol consumption: A meta-regression. *Annals of Behavioral Medicine, 52*(6), 530–543.

Gollwitzer, P. M. (1999). Implementation intentions: Strong effects of simple plans. *American Psychologist, 54*(7), 493–503.

Gollwitzer, P. M., & Sheeran, P. (2006). Implementation intentions and goal achievement: A meta-analysis of effects and processes. *Advances in Experimental Social Psychology, 38*, 69–119.

Hufford, M. R., Shields, A. L., Shiffman, S., Paty, J., & Balabanis, M. (2002). Reactivity to ecological momentary assessment: An example using undergraduate problem drinkers. *Psychology of Addictive Behaviors, 16*(3), 205–211.

Kaner, E. F. S., Beyer, F. R., Garnett, C., et al. (2017). Personalised digital interventions for reducing hazardous and harmful alcohol consumption in community-dwelling populations. *Cochrane Database of Systematic Reviews, 2017*(9), CD011479.

Michie, S., Richardson, M., Johnston, M., Abraham, C., Francis, J., Hardeman, W., Eccles, M. P., Cane, J., & Wood, C. E. (2013). The behavior change technique taxonomy (v1) of 93 hierarchically clustered techniques: Building an international consensus for the reporting of behavior change interventions. *Annals of Behavioral Medicine, 46*(1), 81–95.

Miller, W. R., & Rose, G. S. (2015). Motivational interviewing and decisional balance: Contrasting responses to client ambivalence. *Behavioural and Cognitive Psychotherapy, 43*(2), 129–141. https://doi.org/10.1017/S1352465813000878

Oldham, M., Beard, E., Loebenberg, G., Dinu, L., Angus, C., Burton, R., Field, M., Greaves, F., Hickman, M., Kaner, E., Michie, S., Munafò, M., Pizzo, E., Brown, J., & Garnett, C. (2024). Effectiveness of a smartphone app (Drink Less) versus usual digital care for reducing alcohol consumption among increasing-and-higher-risk adult drinkers in the UK: A two-arm, parallel-group, double-blind, randomised controlled trial. *eClinicalMedicine, 70*, 102534. https://doi.org/10.1016/j.eclinm.2024.102534

Riper, H., Spek, V., Boon, B., et al. (2011). Effectiveness of E-self-help interventions for curbing adult problem drinking: A meta-analysis. *Journal of Medical Internet Research, 13*(2), e42.

Sandberg, T., & Conner, M. (2008). Anticipated regret as an additional predictor in the theory of planned behaviour: A meta-analysis. *British Journal of Social Psychology, 47*(4), 589–606. https://doi.org/10.1348/014466607X258704

Shiffman, S. (2009). Ecological momentary assessment (EMA) in studies of substance use. *Psychological Assessment, 21*(4), 486–497.
