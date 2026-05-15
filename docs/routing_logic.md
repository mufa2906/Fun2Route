# Routing Logic Documentation - Fun2Route (Evolution)

This document outlines the shift from **Geometry-First** to **Environment-First** routing logic.

## 🧠 Philosophy Shift
*   **Old Logic**: "Geometry-First" — Generate a triangle/shape and force OSRM to follow it. Resulted in robotic, unnatural paths.
*   **New Logic**: "Environment-First" — Use road-snapping anchors and a "Pleasantness" scoring system to favor natural walking flows.

---

## 1. Core Engine
We use the **OSRM (Open Source Routing Machine)** public API with the `bike` profile and `alternatives=true`.

*   **Why `bike`?**: Surprisingly good choice compared to `foot` (which often returns chaos, tiny alleys, and absurd gaps). Bike profile ensures road continuity, calmer segments, and predictability.
*   **Alternatives**: We fetch multiple route candidates to evaluate the "most pleasant" flow rather than purely the shortest mathematical path.

---

## 🎯 Implementation Roadmap (The Pleasantness Engine)

### 🚨 PHASE 1: Improve Route Scoring (CRITICAL) - **In Progress**
The immediate focus is improving how we evaluate routes, optimizing for walking flow rather than strict geometry.

**Penalize:**
*   **Overlap**: Psychologically frustrating self-intersections.
*   **Zig-Zag**: High point density representing robotic/unnatural geometry.
*   **Sharp Turns**: Repetitive micro-turns and crossing chaos.

**Reward:**
*   **Continuity & Readability**: Paths that feel cohesive and purposeful.
*   **Flow**: Smooth progression towards the target distance without artificial dead-zones.

*(Note: Distance Penalty, Sharp Turn Penalty, Zig-Zag Penalty, and Overlap Penalty are actively implemented in `route_provider.dart`)*

### 🚀 PHASE 2: Replace Triangle Logic Gradually
The concept of "geometry-first routing" (generating shapes and forcing paths to fit them) must be eventually deprecated.
*   **Anchor-Based Generation**: Pick pleasant areas/intersections and connect them logically.
*   **Flow-Based Loops**: Allow the road hierarchy to naturally guide a path back to the start, rather than offsetting points mathematically.

### 🎭 PHASE 3: Build Route Personality System
Make routes feel distinct based on user mood:
*   *Smooth Jog*: Long straights, few turns.
*   *Evening Stroll*: Quieter roads, shorter blocks, simpler loop.
*   *Explorer*: Moderate novelty, more neighborhood variation.

### 🧠 PHASE 4: Personal Route Memory
Future integration for remembering favored routes and adapting to the user's localized preferences.

---

## 5. Visual Rendering
*   **Overlapping Detection**: We use a pseudo-gradient trick (Wide/transparent outbound line + Thin/solid inbound line). This solves the visual mess of overlapping segments and will remain a core part of the UI, even though overlapping itself is penalized mathematically.
