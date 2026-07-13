# Klar — MVP-Konzept v2

**Arbeitstitel:** Klar (Namensprüfung DPMA/App Store ausstehend)
**Kategorie:** Konsum-Bewusstsein & Risikominimierung
**Plattform:** iOS (SwiftUI, local-first), deutscher Markt zuerst
**Altersfreigabe:** 17+
**Stand:** Juli 2026 — ersetzt Abschnitt 7 („MVP cut") des Konzeptdokuments v1

---

## 1. Zusammenfassung der Änderungen gegenüber v1

Das MVP wird auf Basis der Evidenzlage zu digitalen Verhaltensänderungs-Interventionen umgebaut. Die zentralen Änderungen:

1. **Action Planning (Wenn-Dann-Pläne) wird MVP-Kernfeature** — es ist die einzige Komponente, für die in Kombination mit Self-Monitoring ein experimenteller Wirknachweis auf App-Ebene existiert (Crane et al., 2018).
2. **Der Weekly Review wandert von v1.1 ins MVP** — Selbstbeobachtung ohne Rückmeldung ist laut Evidenz weitgehend wirkungslos (Buu et al., 2020).
3. **Behavior Substitution und Problem Solving** werden als leichtgewichtige Module ergänzt — die beiden Techniken mit der konsistentesten Assoziation zu Konsumreduktion (Garnett et al., 2018; Kaner et al., 2017).
4. **Risikoinhalte werden neu begründet**: als Public-Health- und Notfallfunktion, nicht als Reduktionshebel — Informationen über Konsumfolgen sind mit *kleineren* Interventionseffekten assoziiert (Black et al., 2016).
5. **Normatives Feedback wird explizit ausgeschlossen** (Begründung in § 3.4).

---

## 2. Wissenschaftlicher Hintergrund

### 2.1 Reine Dokumentation verändert Konsum kaum („Measurement Reactivity")

Die Frage, ob das bloße Protokollieren von Konsum das Verhalten verändert, ist in der Forschung zu Ecological Momentary Assessment (EMA) gut untersucht — mit ernüchterndem Ergebnis. Shiffman (2009) resümiert in seinem Überblick zur EMA-Methodik bei Substanzkonsum, dass Studien bislang keine starken Reaktivitätseffekte gezeigt haben; selbst bei Rauchern unmittelbar vor einem Aufhörversuch — einer Population, in der Reaktivität maximal sein sollte — fand sich nur eine Reduktion von etwa 0,3 Zigaretten pro Tag ohne Veränderung biochemischer Marker. Für Problemtrinker berichten Hufford, Shields, Shiffman, Paty und Balabanis (2002) ebenfalls keine belastbare Reaktivität des Selbstmonitorings.

Das methodisch sauberste Experiment hierzu stammt von Buu et al. (2020): 307 Teilnehmende wurden randomisiert täglichen oder wöchentlichen Tagebuch-Erhebungen zugeteilt. Ergebnis: kurzfristige Reaktivität beim Alkoholkonsum, **keine** messbare Reaktivität beim Cannabiskonsum. Die Autor:innen führen das Ausbleiben nachhaltiger Effekte explizit darauf zurück, dass **kein Feedback** (z. B. grafische Aufbereitung der Verhaltensmuster) bereitgestellt wurde.

> **Produktkonsequenz:** Das Tagebuch ist Input, nicht Wirkmechanismus. Ein Logging-Feature ohne Feedback-Schicht ist verhaltenswissenschaftlich wertlos.

### 2.2 Digitale Interventionen wirken — aber moderat

Meta-analytisch ist die Wirksamkeit digitaler Selbsthilfe zur Konsumreduktion (Alkohol) gut belegt, die Effektstärken sind jedoch bescheiden. Riper et al. (2011) finden über neun RCTs zu internetbasierter Selbsthilfe ohne Therapeutenkontakt einen mittleren Gesamteffekt von g = 0,44. Donoghue, Patton, Phillips, Deluca und Drummond (2014) bestätigen die Wirksamkeit elektronischer Kurzinterventionen (eSBI), zeigen aber, dass die Effekte über die Zeit abnehmen. Der Cochrane-Review von Kaner et al. (2017) kommt für personalisierte digitale Interventionen zu einem ähnlichen Bild: wirksam, aber mit Effektgrößen im Bereich weniger Standardgetränke pro Woche.

Die bislang größte App-Einzelevaluation ist der Drink-Less-RCT (Oldham et al., 2024; n = 5.602): Die konservative Intention-to-treat-Analyse ergab eine statistisch nicht signifikante Mehrreduktion von 0,98 UK-Einheiten/Woche gegenüber der NHS-Webseite; die präregistrierte Sensitivitätsanalyse mit multipler Imputation zeigte eine signifikante Mehrreduktion von 2,00 Einheiten/Woche. Zur Einordnung: Beide Gruppen reduzierten im Studienverlauf um rund 37–39 Einheiten pro Woche — der App-spezifische Zusatzeffekt ist real, aber klein relativ zur Eigenmotivation der Nutzer:innen.

> **Produktkonsequenz:** Realistische Erwartungshaltung. Die App ist ein Verstärker für Menschen, die reduzieren *wollen* — kein Ersatz für Motivation und keine Behandlung. Genau so wird sie auch kommuniziert (intern, im Store, gegenüber App Review).

### 2.3 Welche Komponenten wirken: die Evidenz zu Behavior Change Techniques (BCTs)

Die Interventionsforschung zerlegt Programme in standardisierte Einzeltechniken (BCT-Taxonomie v1; Michie et al., 2013). Für digitale Alkohol-Interventionen zeigen zwei zentrale Synthesen ein konsistentes Muster:

- Die Meta-Regression von Garnett et al. (2018) über 41 digitale Interventionen findet **„Behavior Substitution", „Problem Solving" und „Credible Source"** mit stärkerer Konsumreduktion assoziiert. „Self-Monitoring" (in nur 29 % der Studien eingesetzt) und „Goal Setting" (43 %) gelten als wirksam, aber auffallend selten implementiert.
- Kaner et al. (2017) identifizieren **Goal Setting, Problem Solving, Information about Antecedents und Behavior Substitution** als signifikant mit reduziertem Konsum assoziierte Techniken.
- Black, Mullan und Sharpe (2016) finden in ihrer Meta-Regression über 93 computerbasierte Interventionen größere Effekte bei Commitment/Zielüberprüfung und normativem Feedback — aber **kleinere Effekte, wenn Informationen über die Konsequenzen des Konsums vermittelt wurden**.

Die präziseste Komponentenevidenz auf App-Ebene liefert der 2⁵-faktorielle RCT zur Drink-Less-App (Crane, Garnett, Michie, West & Brown, 2018; n = 672), in dem fünf Module einzeln in „enhanced"- vs. Minimalversion getestet wurden. Ergebnis: **keine signifikanten Haupteffekte einzelner Module** — aber eine signifikante Interaktion zwischen **Self-Monitoring & Feedback und Action Planning** auf den AUDIT-Score. Zugleich wurde das Self-Monitoring-Modul signifikant häufiger genutzt und deutlich besser bewertet (Hilfreichkeit, Zufriedenheit, Weiterempfehlung) als alle anderen Module.

> **Produktkonsequenz — das Kernargument dieses Dokuments:** Self-Monitoring ist der **Retention-Motor** (es wird genutzt und geschätzt), aber nicht der Wirkmechanismus. Wirkung entsteht in der **Kombination mit Action Planning**. Ein MVP, das nur trackt, baut die Hälfte des belegten Wirkprinzips.

### 2.4 Warum Action Planning: Implementation Intentions

Action Planning operationalisiert das Konzept der *Implementation Intentions* (Gollwitzer, 1999): konkrete Wenn-Dann-Pläne („Wenn Situation X eintritt, dann tue ich Y"), die die Handlungsinitiierung von bewusster Willensanstrengung entkoppeln und an situative Auslöser binden. Die Meta-Analyse von Gollwitzer und Sheeran (2006) über 94 Studien zeigt einen mittleren bis großen Effekt von Implementation Intentions auf die Zielerreichung (d = 0,65) — einer der robustesten Befunde der Selbstregulationsforschung überhaupt. In der BCT-Taxonomie entspricht dies der Technik „Action Planning" (1.4; Michie et al., 2013).

Für den Konsumkontext ist der Mechanismus besonders passend: Konsumentscheidungen fallen häufig in Situationen mit reduzierter Selbstkontrolle (Club, Gruppendruck, Craving). Ein vorab formulierter, situationsgebundener Plan verlagert die Entscheidung in einen Moment mit voller Selbstkontrolle.

### 2.5 Grenzen der Evidenz

Drei Einschränkungen sind für dieses Projekt konstitutiv und werden nicht wegdiskutiert:

1. **Substanz-Übertragbarkeit:** Nahezu die gesamte zitierte Evidenz stammt aus der Alkohol- und Tabakforschung. Für MDMA, Kokain, Ketamin u. a. existieren keine RCTs zu App-basierter Konsumreduktion. Die Kernannahme von Klar ist eine plausible Extrapolation, kein belegter Sachverhalt.
2. **Selbstselektion:** Alle Studien rekrutierten reduktionsmotivierte Teilnehmende. Über Effekte bei nicht veränderungsbereiten Konsument:innen sagt die Evidenz nichts.
3. **Effektgrößen:** Auch im besten Fall sind die Zusatzeffekte digitaler Interventionen klein (§ 2.2). Marketing- und Store-Kommunikation dürfen keine Wirkversprechen enthalten — auch aus Compliance-Gründen (keine Health Claims, keine Medical-Positionierung).

---

## 3. Ableitung: Designprinzipien für das MVP

| # | Prinzip | Evidenzbasis |
|---|---|---|
| P1 | Logging ist Input, nie Selbstzweck; jede Erfassung mündet in Feedback | Buu et al. (2020); Shiffman (2009) |
| P2 | Self-Monitoring + Action Planning werden als Paar gebaut und im UI verzahnt | Crane et al. (2018) |
| P3 | Behavior Substitution und Problem Solving als leichtgewichtige Begleitmodule | Garnett et al. (2018); Kaner et al. (2017) |
| P4 | Kein normatives Feedback | keine validen Normdaten für illegale Substanzen; Backfire-Risiko („ich liege ja unterm Schnitt"); der positive Befund bei Black et al. (2016) bezieht sich auf Alkohol mit belastbaren Referenzwerten |
| P5 | Risikoinhalte sind Notfall- und Public-Health-Funktion, kein Reduktionsversprechen | Black et al. (2016): Konsequenz-Aufklärung ist mit kleineren Effekten assoziiert |
| P6 | Inhalte kommen von etablierten Organisationen und werden attribuiert („Credible Source") | Garnett et al. (2018) |
| P7 | Feedback bleibt neutral und am eigenen Baseline-Verlauf orientiert — kein Lob für Konsum, keine Moralisierung | Positionierungsentscheidung v1; konsistent mit P4 |

---

## 4. MVP-Featureset v2

### Modul A — Erfassung (Self-Monitoring)
- 2-Tap-Logging: „+" → Substanz → gespeichert; Zeitstempel automatisch, editierbar
- Dosisfeld (mg/g/ml, selbstberichtet), Kontext-Tags (allein/sozial/Club/zuhause), überspringbar
- Vorbefüllte Substanzliste, persönliche Auswahl im Onboarding, eigene Einträge möglich
- Kalenderansicht: eintragsfreie Tage als visuell positiver Grundzustand

### Modul B — Feedback (neu priorisiert, war v1.1)
- **Weekly Review als Pflichtbestandteil des MVP**: neutrale Wochenzusammenfassung (Einträge, Ø-Dosis-Trend, Abstände zwischen Konsumereignissen, Zielfortschritt)
- Trends pro Substanz: Frequenz, Ø-Dosis über Zeit, Lücken
- Referenzpunkt ist ausschließlich die eigene Baseline (P7)

### Modul C — Action Planning (neu)
- Wenn-Dann-Pläne, an Kontext-Tags aus Modul A gekoppelt:
  - *Situationspläne:* „Wenn ich im Club bin und mir jemand etwas anbietet, dann sage ich: ‚Heute nicht.'"
  - *Craving-Pläne:* „Wenn ein Craving kommt, dann starte ich den 20-Minuten-Timer und gehe eine Runde."
  - *Mengenpläne:* „Wenn ich konsumiere, dann höchstens die Hälfte der letzten Dosis."
- Bibliothek mit Plan-Vorlagen (editierbar), max. 3 aktive Pläne — Fokus statt Liste
- Verzahnung mit Modul A: Nach einem Eintrag mit passendem Kontext-Tag fragt die App beim nächsten Öffnen neutral, ob der Plan geholfen hat (Ja/Nein/Plan anpassen) → Plan-Iteration als Kern-Loop
- Verzahnung mit Modul B: Weekly Review zeigt Plan-Erfolgsquote

### Modul D — Ziele & Reduktion
- Ein Zieltyp im MVP: Frequenzreduktion („max. 1× / Monat") pro Substanz; Abstinenzziel als Spezialfall (0×)
- Eintragsfreie Serien, Meilensteine, Geld-gespart-Schätzung (nutzerdefinierte Kostenbasis)

### Modul E — Craving-SOS (erweitert um Behavior Substitution & Problem Solving)
- Urge-Surfing-Timer, Atemübung, eigene „Warum"-Notizen, Ein-Tap-Anruf an selbstgewählten Kontakt
- **Behavior Substitution:** Nutzer:in hinterlegt im Onboarding 2–3 Ersatzhandlungen („rausgehen", „Freund:in schreiben", „duschen"); SOS-Screen schlägt genau diese vor
- **Problem Solving:** Nach einem Eintrag, der ein Ziel verfehlt, ein optionaler 3-Fragen-Reflexionsflow (Was war der Auslöser? Was hätte geholfen? Was änderst du am Plan?) → mündet direkt in Modul C

### Modul F — Notfall & Beratung (Public-Health-Schicht)
- Notfall-Screen: Warnzeichen erkennen, Erste-Hilfe-Schritte, Ein-Tap-112
- Suchtberatungs-Verzeichnis (DE, statisch in v1), Sucht & Drogen Hotline
- Risikohinweise pro Substanz im Starter-Set (5–8 Substanzen): ausschließlich Gefahrenvermeidung, gefährliche Kombinationen, Notfallsymptome; Quellen attribuiert (BZgA/drugcom.de, mindzone, Saferparty) — **keine Dosisempfehlungen, keine Wirkoptimierung** (vgl. Produktverfassung v1, § 5)

### Modul G — Privatsphäre
- Local-first, kein Account, kein Server; Face-ID-Sperre; Panik-Verbergen; vollständiger Export (JSON/CSV) und echte Löschung
- Optionaler iCloud-Sync (privater CloudKit-Container) nach MVP

### Explizit nicht im MVP
Widgets, EN-Lokalisierung, Drug-Checking-Alerts (Lizenzierung), Forschungs-Datenspende (erst mit akademischem Partner und Ethikvotum, siehe Diskussionsstand), Apple-Health-Integration. **Dauerhaft ausgeschlossen** bleiben alle Punkte der Produktverfassung (v1, § 5): Dosisempfehlungen, „How-to"-Inhalte, soziale Feeds, Beschaffungshilfen, normatives Feedback (§ 3, P4).

---

## 5. Validierung

Unverändert zu v1, mit einer Ergänzung: Neben Retention (≥ 50 % loggen noch in Woche 4 bei ≥ 20 Testnutzer:innen über 4+ Wochen) wird die **Nutzung von Action Planning** als eigenständige Validierungsmetrik erhoben (Anteil Nutzer:innen mit ≥ 1 aktivem Plan nach Woche 2; Plan-Iterationsrate). Begründung: Wenn das SM+AP-Paar der Wirkmechanismus ist (§ 2.3), ist AP-Adoption der früheste Indikator dafür, dass das Produkt mehr ist als ein Tagebuch.

---

## 6. Limitationen dieses Dokuments

Dieses Konzept überträgt Evidenz aus der Alkohol-/Tabakforschung auf illegale Substanzen (§ 2.5). Es ist kein medizinisches Produkt, keine Behandlung und erhebt keinen therapeutischen Anspruch. Die zitierten Effektgrößen beziehen sich auf andere Substanzen, andere Populationen und teils andere Interventionsformate; sie begründen Designentscheidungen, keine Wirkversprechen. Eine Evaluation im eigenen Anwendungskontext (perspektivisch mit akademischem Partner) ist der einzige Weg, diese Lücke zu schließen.

---

## Literaturverzeichnis

Black, N., Mullan, B., & Sharpe, L. (2016). Computer-delivered interventions for reducing alcohol consumption: Meta-analysis and meta-regression using behaviour change techniques and theory. *Health Psychology Review, 10*(3), 341–357. https://doi.org/10.1080/17437199.2016.1168268

Buu, A., Yang, S., Li, R., Zimmerman, M. A., Cunningham, R. M., & Walton, M. A. (2020). Examining measurement reactivity in daily diary data on substance use: Results from a randomized experiment. *Addictive Behaviors, 102*, 106198. https://doi.org/10.1016/j.addbeh.2019.106198

Crane, D., Garnett, C., Michie, S., West, R., & Brown, J. (2018). A smartphone app to reduce excessive alcohol consumption: Identifying the effectiveness of intervention components in a factorial randomised control trial. *Scientific Reports, 8*, 4384. https://doi.org/10.1038/s41598-018-22420-8

Donoghue, K., Patton, R., Phillips, T., Deluca, P., & Drummond, C. (2014). The effectiveness of electronic screening and brief intervention for reducing levels of alcohol consumption: A systematic review and meta-analysis. *Journal of Medical Internet Research, 16*(6), e142. https://doi.org/10.2196/jmir.3193

Garnett, C., Crane, D., Brown, J., et al. (2018). Behavior change techniques used in digital behavior change interventions to reduce excessive alcohol consumption: A meta-regression. *Annals of Behavioral Medicine, 52*(6), 530–543.

Gollwitzer, P. M. (1999). Implementation intentions: Strong effects of simple plans. *American Psychologist, 54*(7), 493–503.

Gollwitzer, P. M., & Sheeran, P. (2006). Implementation intentions and goal achievement: A meta-analysis of effects and processes. *Advances in Experimental Social Psychology, 38*, 69–119.

Hufford, M. R., Shields, A. L., Shiffman, S., Paty, J., & Balabanis, M. (2002). Reactivity to ecological momentary assessment: An example using undergraduate problem drinkers. *Psychology of Addictive Behaviors, 16*(3), 205–211.

Kaner, E. F. S., Beyer, F. R., Garnett, C., et al. (2017). Personalised digital interventions for reducing hazardous and harmful alcohol consumption in community-dwelling populations. *Cochrane Database of Systematic Reviews, 2017*(9), CD011479.

Michie, S., Richardson, M., Johnston, M., Abraham, C., Francis, J., Hardeman, W., Eccles, M. P., Cane, J., & Wood, C. E. (2013). The behavior change technique taxonomy (v1) of 93 hierarchically clustered techniques: Building an international consensus for the reporting of behavior change interventions. *Annals of Behavioral Medicine, 46*(1), 81–95.

Oldham, M., Beard, E., Loebenberg, G., Dinu, L., Angus, C., Burton, R., Field, M., Greaves, F., Hickman, M., Kaner, E., Michie, S., Munafò, M., Pizzo, E., Brown, J., & Garnett, C. (2024). Effectiveness of a smartphone app (Drink Less) versus usual digital care for reducing alcohol consumption among increasing-and-higher-risk adult drinkers in the UK: A two-arm, parallel-group, double-blind, randomised controlled trial. *eClinicalMedicine, 70*, 102534. https://doi.org/10.1016/j.eclinm.2024.102534

Riper, H., Spek, V., Boon, B., et al. (2011). Effectiveness of E-self-help interventions for curbing adult problem drinking: A meta-analysis. *Journal of Medical Internet Research, 13*(2), e42.

Shiffman, S. (2009). Ecological momentary assessment (EMA) in studies of substance use. *Psychological Assessment, 21*(4), 486–497.
