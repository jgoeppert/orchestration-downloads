# Public transport boundary

This repository is intentionally public. Treat every committed object as permanently public, even after later deletion.

Allowed content: generic transport code plus non-secret run identifiers, repository names, refs, commit SHAs, and private-helper paths.

Forbidden content: credentials or tokens, private keys, cookies or auth headers, environment dumps, private repository file contents, patches, logs, task payloads, customer/internal data, signed URLs, or other secrets.

Public transport must fetch the actual execution helper from the private repository and verify exact ref/SHA before execution.
