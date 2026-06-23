---
name: connected-function-cx-library
description: Structure shared code across all connected functions in a Skedulo project using the `@cx` shared library pattern. Use this skill when working in a project that has (or should have) a `src/cx/` shared library symlinked into each function — typed models, a service factory, object definitions, centralized configuration management, and date utilities — or when the user mentions `@cx`, the cx library, or cross-function shared code.
---

# Connected Function — @cx Shared Library

`@cx` is a pattern for structuring code shared across all connected functions in a Skedulo project. The library lives at `src/cx/`, is symlinked into each function directory, and provides:

- Typed models for Skedulo objects
- A service factory for Skedulo API access
- Object definitions
- Centralized configuration management
- Date/time utilities

Use it to avoid duplicating models, config, and service wiring across functions in the same project.

## Full reference

See **[references/cx-library.md](references/cx-library.md)** for the directory structure, the service factory, object-definition patterns, configuration management, and complete examples.
