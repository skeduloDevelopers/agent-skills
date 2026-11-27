# Optimization Extension Review Checklist

Judgement items — read the code rather than grepping for patterns.

- **Transformer contract**: the handler returns both `featureModel` and `productData`; nothing that
  should be read-only (`plan`, `configuration`) is mutated in place.
- **Allocation matching**: wherever allocations join jobs, the `_<n>` suffix is stripped before the
  comparison.
- **API budget**: the data access fits the 50-call / 5-concurrent / 12s envelope — reads are batched,
  not one query per job or resource.
- **Configuration**: every tunable comes from a declared config var, loaded once at the top of the
  handler; nothing hardcoded, nothing read from `process.env`; each var used in code is declared in
  `sked.proj.json → settings.configVars`.
- **ExecutionContext**: constructed from `TransformerInput` credentials before first use.
- **Complexity in the hot path**: per-job and per-resource lookups use `Map`/`Set` rather than
  repeated `Array.find`/`includes` scans over the plan.
- **Error handling**: failures return a 5xx transformer response rather than throwing past the
  handler; the message says which stage failed.
- **Tests** exercise the transform contract — at minimum one case asserting both returned keys and
  one asserting the filtering/constraint behaviour the extension exists for.
- **SPEC.md** matches what's implemented.
