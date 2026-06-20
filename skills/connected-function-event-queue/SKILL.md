---
name: connected-function-event-queue
description: Handle large or bursty Skedulo triggered-action payloads asynchronously in a connected function using an event queue. Use this skill when a triggered action may deliver many records at once and risks timeouts, when you need to enqueue work and process it in controlled-size batches, or when implementing a queue receiver + worker pattern (bulk enqueue, async delivery) instead of processing records synchronously in the handler.
---

# Connected Function — Event Queueing

The Skedulo platform delivers triggered-action payloads synchronously — if your handler is slow, or the platform batches many records in one shot, you risk timeouts and dropped work. The event queue decouples receipt from processing:

- The manifest posts records to a **queue receiver** instead of directly to your handler.
- A separate **worker** pulls from the queue and delivers records to your handler in controlled-size batches.

Use this whenever a triggered action can fan out over a large or unpredictable number of records.

## Full reference

See **[references/event-queueing.md](references/event-queueing.md)** for the end-to-end flow, queue/worker wiring, batch-size tuning, and complete examples.

Pairs with the **connected-function-triggered-actions** skill (the manifest that feeds the queue).
