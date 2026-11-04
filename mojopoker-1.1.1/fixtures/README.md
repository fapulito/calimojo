# Copyright (C) 2026, California Vision

Forecast fixtures (Session 2). Play-money demo data.

- `fc_headlines.json` — trending non-sports headlines by topic
  (economics, tech, culture, weather). Input for draft generation.
- `fc_draft_questions.json` — canned model output for the `draft_questions`
  operation. Returned verbatim when `FORECAST_FIXTURE=1`.
- `fc_sources.json` — default source snippets handed to the model at
  resolve time.
- `fc_resolve.json` — canned model output for the `resolve` operation
  (outcome + reasoning + sources used).

JSON files cannot carry comment headers; this README is the licence marker
for the fixture data.
