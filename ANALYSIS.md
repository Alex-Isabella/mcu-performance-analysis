# MCU Performance Analysis: Methodology & Findings

## 1. Motivation

Since roughly 2021, there's been a persistent media narrative that the Marvel Cinematic Universe is suffering from "franchise fatigue", that audiences have grown tired of the volume and sameness of Marvel content, and that this is showing up in box office and critical reception. This is usually stated as received wisdom rather than something anyone has actually measured.

This project set out to test that narrative directly: is there a measurable decline, and if so, what's actually driving it? The goal wasn't to confirm the fatigue story, it was to see what the data said, even if that meant complicating or rejecting the popular framing.

## 2. Data

### Sources
- **TMDB** — film metadata: runtime, director, genres, popularity, cast (top 10 billed per film)
- **OMDb** — IMDb rating, Rotten Tomatoes score, Metascore
- **The Numbers** — budget, opening weekend, domestic gross, worldwide gross

### Scope
All 36 MCU theatrical films released as of data collection, Phase One through Phase Five. Phase Six was excluded from era-comparison analysis because, at the time of collection, only one Phase Six film (*Fantastic Four*) had released, a sample size of one is not large enough to characterize a "phase."

### A data-quality note worth flagging
*Captain America: Brave New World* was initially mislabeled as a Phase Six film in this project's seed data. This was caught and corrected after cross-referencing Marvel's official phase groupings, which place it in Phase Five alongside *Thunderbolts\**. The correction is preserved in `sql/03_fix_phase_mislabel.sql` rather than silently edited out, since being transparent about a caught and fixed error is more credible than pretending the dataset was perfect from the start.

### Database design
Data was loaded into a normalized PostgreSQL schema — five tables (`films`, `film_details`, `film_cast`, `ratings`, `financials`) joined on film title, with foreign-key constraints enforcing referential integrity. Text-formatted fields from the source APIs (e.g., Rotten Tomatoes scores arriving as `"94%"`, IMDb vote counts as `"1,223,183"`) were converted into clean numeric columns via a dedicated cleaning pass before any analysis was run on them.

## 3. Methodology

Four core analyses were run via SQL against the joined dataset:

1. **Critic vs. audience score gap by phase** — comparing average Rotten Tomatoes score (0-100) against average IMDb rating (scaled ×10 to the same range), grouped by phase
2. **ROI by phase** — average worldwide gross ÷ average budget per phase, with a reference threshold acknowledging that real breakeven for a theatrical release typically requires roughly 2-2.5x budget once marketing and distribution costs (not present in this dataset) are included
3. **Actor appearance-gap analysis** — using a `LAG()` window function partitioned by actor and ordered by release date, calculating the number of days between a top-3-billed actor's consecutive MCU appearances, then comparing that gap against the receiving film's reception scores
4. **Phase 1-3 vs. Phase 4-5 cohort comparison** — a direct two-group comparison across critic score, audience score, ROI, and runtime, to test multiple competing explanations side by side

A fifth pass added Pearson correlation coefficients (via Postgres's built-in `CORR()`) between reception and ROI, and between budget and reception, to quantify relationships that earlier queries had only shown visually.

## 4. Findings

### 4.1 The critic-audience gap does not widen over time — it's widest at the franchise's peak

| Phase | Avg. critic score | Avg. audience score (scaled) | Gap |
|---|---|---|---|
| One | 80.3 | 72.2 | 8.2 |
| Two | 80.8 | 73.3 | 7.5 |
| Three | 89.2 | 75.7 | **13.5** |
| Four | 76.1 | 68.3 | 7.9 |
| Five | 67.0 | 66.0 | **1.0** |

This was the first finding that complicated the project's starting hypothesis. The popular fatigue narrative implies critics and audiences are *splitting apart* over time — but the data shows the opposite: the gap is largest during Phase Three (widely considered the franchise's creative and commercial peak) and smallest during Phase Five. Critics and audiences aren't diverging in recent phases; if anything, they're converging on a shared, lower opinion.

**What this means:** the decline isn't "audiences turned on Marvel while critics stayed loyal" (or vice versa). It's a shared drop in perceived quality across both groups.

### 4.2 ROI has fallen below the franchise's own starting point

| Phase | Avg. budget | Avg. worldwide gross | Avg. ROI multiple |
|---|---|---|---|
| One | $168M | $634M | 3.52x |
| Two | $198M | $876M | 4.49x |
| Three | $212M | $1.22B | **5.58x** |
| Four | $207M | $816M | 3.95x |
| Five | $213M | $611M | **2.94x** |

Phase Five's average ROI (2.94x) is lower than Phase One's (3.52x) — despite Phase One launching the franchise from zero brand recognition, while Phase Five benefits from 15+ years of audience familiarity and one of the most recognizable entertainment brands in the world. Budgets across phases are roughly comparable (~$170-213M average), so this isn't a story of recent films simply costing more without comparable returns — gross itself has fallen.

The single lowest-performing film in the dataset is *The Marvels* (0.76x — it did not gross its own budget back worldwide, before any marketing spend is considered). The single highest is *Spider-Man: No Way Home* (9.61x), which suggests the franchise can still produce outsized commercial successes — the issue isn't universal across Phase 4-5, but the phase averages are clearly down.

### 4.3 Runtime is not the explanation

| | Phase 1-3 | Phase 4-5 | Change |
|---|---|---|---|
| Avg. runtime | 131 min | 133 min | +2 min (essentially flat) |

A common secondary theory is that Marvel films have gotten longer and more bloated, and that this is contributing to audience fatigue. The data doesn't support this — runtime is essentially unchanged between eras. This doesn't rule out *narrative* bloat (more subplots, more setup for future films packed into the same runtime), which this dataset can't measure, but it does rule out simple length as a driver.

### 4.4 Actor appearance gaps show no clean, consistent relationship with reception

This analysis tested a specific version of the fatigue hypothesis: that long gaps between a lead actor's MCU appearances correlate with worse critical/audience reception for their return — e.g., the idea that audiences need consistent reinforcement of a character to stay invested.

The scatter of (days since last top-billed appearance) against (Rotten Tomatoes score) shows no strong or consistent pattern. Some long-gap appearances scored well (Sebastian Stan, ~5,000-day gap, scored well above 90 in *Thunderbolts\**); others scored poorly. Short-gap appearances similarly span the full range of outcomes.

**This is reported as a negative finding rather than omitted.** It would have been easy to leave this analysis out of the final write-up since it doesn't support a tidy story — but a project that only reports confirming results is less credible than one that shows what was tested and didn't pan out. One caveat: this analysis only considers top-3-billed theatrical appearances. Several actors (e.g., Sebastian Stan) had Disney+ series appearances between theatrical films that aren't captured here, which means some "gaps" in this dataset are larger than the character's actual gap in audience visibility.

### 4.5 Correlation: reception and ROI move together, but not perfectly — and budget isn't buying better reviews

Pearson correlation coefficients (via Postgres's `CORR()`) quantify what the phase-level averages suggest visually:

| Relationship | Pearson's r | r² |
|---|---|---|
| Critic score vs. ROI | 0.538 | 0.29 |
| Audience score vs. ROI | **0.643** | 0.41 |
| Critic score vs. audience score | 0.817 | — |
| Budget vs. critic score | 0.016 | — |
| Budget vs. audience score | 0.218 | — |

Three things stand out:

1. **Audience score correlates with ROI more strongly than critic score does** (0.643 vs. 0.538). Word-of-mouth/audience sentiment tracks financial outcome more closely than critical reception does — intuitive, but worth having quantified rather than assumed.
2. **Budget has essentially no relationship with critic score** (r = 0.016) and only a weak one with audience score (r = 0.218). This was run specifically as a confound check: if bigger budgets simply bought better reviews, that would undercut the claim that Phase 4-5's reception decline reflects something real rather than a side effect of spending less. The data clears this — Phase 4-5 budgets are comparable to earlier phases (see 4.2), and budget size doesn't meaningfully predict reception in either direction.
3. **Critic and audience scores correlate strongly with each other** (r = 0.817), consistent with the finding in 4.1 that the gap between them, while real, is modest relative to how much the two groups generally agree.

With only 36 films, a single outlier — notably *Avengers: Endgame*, which is extreme on both reception and ROI — has some influence on these coefficients. The relationships are directionally consistent with the phase-level averages reported elsewhere in this document, but should be read as moderate-confidence estimates given the sample size, not precise population parameters.

## 5. What this analysis rules in and rules out

| Explanation | Supported by data? |
|---|---|
| Audiences and critics are splitting apart | **No** — gap narrows in later phases |
| Films have gotten longer/more bloated (by runtime) | **No** — runtime is flat |
| Long gaps between a lead's appearances hurt reception | **Inconclusive** — no consistent pattern, and gap measurement is incomplete (theatrical-only) |
| A genuine, shared decline in perceived quality, independent of length | **Yes** — both critic and audience scores fall together starting Phase Four |
| Financial returns have fallen even adjusting for budget | **Yes** — ROI is down across Phase 4-5, and Phase Five is now below Phase One |
| Budget size explains the reception decline | **No** — budget correlates negligibly with both critic score (r=0.02) and audience score (r=0.22) |

## 6. Limitations and honest caveats

- **Small sample.** 36 films total, with as few as 6 films in some phase groupings. Averages and correlations are sensitive to individual outliers.
- **ROI is not profit.** Worldwide gross ÷ budget ignores marketing and distribution costs, which are commonly estimated to roughly double the real breakeven bar for a major theatrical release. All ROI figures here should be read as relative comparisons across phases, not literal profitability.
- **Domestic vs. international data source discrepancies.** Box Office Mojo and The Numbers disagree by small amounts on a handful of films' domestic gross figures (likely due to differing re-release/cutoff handling). This project standardized on The Numbers as the single source for all financial figures to avoid inconsistency, rather than mixing sources.
- **TMDB release dates sometimes differ from US theatrical dates** (likely reflecting international or festival premieres), while box office and budget data are tied to US theatrical release. `films.release_date` was treated as canonical for all phase/timeline analysis.
- **The actor-gap analysis is theatrical-only**, as noted in 4.4, and likely understates true "time since audiences last saw this character" for actors with Disney+ series appearances.
- **This analysis does not establish causation.** It identifies a real, multi-metric decline starting at Phase Four and rules out several specific explanations, but does not claim to fully explain *why* the decline occurred — that would require additional data this project doesn't have (e.g., marketing spend, streaming day-and-date strategy, competitive landscape, audience survey data).

## 7. Tools used

PostgreSQL (schema design, window functions, correlation analysis) · Python (`requests`) for API data collection · Tableau Public for visualization · DBeaver as the SQL client throughout development.
