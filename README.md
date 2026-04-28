# Deep Work App

A simple focus app built with Flutter that helps users plan sessions, reflect after working, and receive a small personalized coach message.

The goal of this project is not to overwhelm the user with complex analytics.  
Instead, the app gives **clear, simple, and helpful guidance** based on focus history, outcomes, reflections, and local learning over time.

---

## Overview

Deep Work App is designed for students and other users who want to understand **when they focus better**, **what kind of work fits certain moments**, and **how to improve their study/work habits**.

The app starts with a **cold-start recommendation system** so it can work even for a new user with no history.  
Then, as the user keeps using the app, it **adapts locally** based on:

- completed sessions
- session outcomes
- reflection notes
- coach feedback
- time-of-day patterns
- category success patterns

This means the app is useful from the beginning, but becomes more personal over time.

---

## Main Idea

The core product idea is very simple:

- the user opens the app
- the app suggests one helpful focus action
- the app learns from what happens next

Instead of showing a large dashboard, the app focuses on **one small coach message** that answers:

1. What should I do now?
2. Is this a good time or a weak time?
3. Is there a better time later?

---

## Features

### Focus Sessions
- create and track focus sessions
- store category, intention, duration, outcome, and reflection
- use past sessions to build personalized recommendations

### Simple Coach Card
- one plain-language recommendation
- suggests a category and session duration
- uses cautious wording when data is weak
- avoids technical or confusing analytics

### Cold Start + Local Personalization
- works even with zero user history
- starts from safe default priors
- updates locally after every completed session
- improves recommendations based on real user behavior

### Reflection-Aware Insights
- stores reflection text
- extracts repeated themes locally
- uses soft human wording when patterns appear
- keeps the experience simple and understandable

### Coach Feedback
- users can mark the coach as:
  - Helpful
  - Not helpful
- optional reason selection helps improve future logic

### ML Shadow Mode
- an experimental ML pipeline exists in the background
- it does **not** replace the live coach in the current version
- it is used for future validation and model development

---

## How the Recommendation System Works

The live recommendation system currently uses:

- **default priors** for new users
- **local personalization** from real user history
- **session outcomes**
- **time block patterns**
- **category success rates**
- **preferred duration buckets**
- **reflection theme counts**
- **coach feedback**

This makes the app functional at launch without requiring a pretrained real-user dataset.

The current production path is:

**default priors + local personalization + simple coach UI**

The future path is:

**real usage data + validated ML + cautious blending later**

---

## Why This Design?

Many productivity apps show too many numbers, charts, and technical insights.

This project takes a different direction:

- less dashboard
- less noise
- more clarity
- more actionable recommendations

The app should feel like a small assistant, not a report.

---

## Tech Stack

- **Flutter**
- **Dart**
- local storage for sessions, feedback, coach snapshots, and shadow predictions
- Python-based ML training pipeline for offline experimentation
- JSON-exported model artifacts for future app-side inference

---

## ML / Personalization Status

### Current Live System
- cold-start priors
- local profile learning
- personalized scoring
- coach message generation

### Current Experimental System
- synthetic-data ML pipeline
- exported JSON logistic regression model
- shadow-mode inference
- local export for future retraining on real usage data

### Important Note
The current app does **not** rely on a fully trained real-user ML model to function.  
This is intentional.

The app is already usable without real training data, and becomes more personalized as the user continues to use it.

---

## Privacy Direction

The app is designed around **local-first personalization**.

Current recommendation updates are based on data stored locally on the device, including:

- sessions
- outcomes
- reflections
- coach feedback
- personalization profile
- shadow prediction logs

This keeps the system practical for a first version while preparing for future validation and model improvements.

---

## Project Structure

This project includes:

- focus session tracking
- coach message logic
- local personalization profile
- coach feedback logging
- ML shadow mode
- export pipeline for real local data
- Python training pipeline for experimentation

---

## Current Goal

The current goal of the project is to build a focus app that is:

- simple
- useful
- adaptive
- explainable
- ready for real user validation

The app is not trying to look “smart” with complex dashboards.  
It is trying to give the user **one helpful next step**.

---

## Future Work

Planned future improvements include:

- validating the ML pipeline on real usage data
- blending ML with heuristics carefully
- improving reflection understanding
- improving recommendation calibration
- refining the coach with real feedback patterns
- possible future on-device model improvements

---

## Status

This project is currently in an active development stage, with the main focus on:

- recommendation quality
- personalization stability
- coach usefulness
- real-world testing
- release readiness

---

## Author

**Gadiel Pugh**

Computer Science student interested in:
- AI
- software engineering
- educational technology
- practical, human-centered intelligent systems

---

## Final Note

Deep Work App is built around one simple belief:

> a productivity app should not just collect data — it should help the user take the next useful step.