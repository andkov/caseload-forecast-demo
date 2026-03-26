# Frontend 3 — Human Intent (Round 1)

**Recorded**: March 19, 2026 (from Interviewer conversation)

## Audience

Branch Learning Session "Lunch Bunch" — diverse group. Some attendees are comfortable with
statistical modeling and forecasting; most are not. Mixed technical fluency.

## Format

Reveal.js slide deck (~30-minute talk, ~9 content slides). Self-contained HTML file.

## What the Talk Should Do

1. Show the **shape of the Income Support caseload signal** — 20 years of history.
2. Walk through **historical periods** using annotated graphs (recessions, oil shock, COVID).
3. Present the **24-month ARIMA forecast** and explain why ARIMA was chosen over the Naive baseline.
4. Anchor the forecast in **concrete numbers** at the 12-month and 24-month marks,
   with uncertainty ranges stated honestly.

## The One Thing

> The shape of the signal and the forecast — and the actual values at 12m and 24m.

## Content Sources

- EDA-2 historical charts (signal shape, period averages, YOY)
- Report-1 forecast charts (hero forecast, model comparison overlay)
- Report-1 model performance table (ARIMA vs Naive metrics)
- Report-1 key forecast numbers table (point forecasts + 95% intervals at horizons)
- Project mission (`ai/project/mission.md`) for Income Support plain-language context

## Tone

Confident and accessible. Let the charts do the heavy lifting. Minimal text per slide.
Honest about uncertainty — the 24-month interval is wide and that is the truth.
