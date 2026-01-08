## Overview

- `any-sync-bundle` wraps the Anytype coordinator, consensus, filenode, and sync services into one binary (`lightnode/anynodes.go`).
- All services share the coordinator's network stack: TCP 33010, QUIC/UDP 33020, one PeerID, one DRPC mux.
- The filenode supports two storage backends (auto-selected based on configuration):
  - **BadgerDB** (default): Local embedded storage via `lightcmp/lightfilenodestore`
  - **S3** (optional): Cloud storage via upstream `s3store` implementation
- External dependencies: MongoDB for coordinator/consensus, Redis for filenode cache. Sync node persists to AnyStore on disk.

Config bootstrap (cmd/start.go):

1. Load existing bundle YAML if present.
2. Otherwise create one via `config.CreateWrite`, injecting values from env/flags.
3. Always write the client config (`YamlClientConfig`) to the target path.

## Architecture Notes

- Coordinator starts first, then consensus, filenode, sync (`runBundleServices`).
- `extractSharedNetwork` copies network components from the coordinator into other apps.
- DRPC routes by method prefix (`/CoordinatorService`, `/ConsensusService`, `/FileService`, `/SpaceSyncService`).
- Data layout (default `./data`):
  - `bundle-config.yml` – persisted configuration (credentials, keys)
  - `client-config.yml` – generated client config (regenerated on start)
  - `storage/` – local storage directory:
    - `network-store/` – network configuration
    - `storage-sync/` – sync node persistence (AnyStore)
    - `storage-file/` – filenode data (BadgerDB, when not using S3)

## Development

### Compose files

- `compose.dev.yml` – development dependencies (MongoDB replica set + Redis Stack).
- `compose.aio.yml` – bundle image with embedded MongoDB/Redis.
- `compose.external.yml` – bundle image plus external MongoDB and Redis containers.
- `compose.s3.yml` – bundle with MinIO for S3 storage testing.
- `compose.traefik.yml` – Traefik reverse proxy example.

```bash
go build -o any-sync-bundle .
golangci-lint run --fix
go test -race -shuffle=on -vet=all -failfast ./...
go test -tags=integration ./integration/...  # requires Docker
```

### Integration Tests

Uses `testcontainers-go` to spin up MongoDB, Redis, and MinIO containers.

Test files:
- `integration/containers.go` – container lifecycle helpers
- `integration/bundle.go` – bundle process manager
- `integration/integration_test.go` – test cases

## Kiro System - Spec-Driven Development

This project uses the **Kiro System** for structured feature development.

### Kiro Workflow (3-Phase Approach)
1. **Requirements** (`requirements.md`) - What needs to be built
2. **Design** (`design.md`) - How it will be built
3. **Tasks** (`tasks.md`) - Step-by-step implementation plan

### Directory Structure
- `.kiro/specs/{feature-name}/` - Individual feature specifications
- `.kiro/kiro-system-templates/` - Templates and documentation
  - `requirements_template.md` - Template for requirements
  - `design_template.md` - Template for technical design
  - `tasks_template.md` - Template for implementation tasks
  - `how_kiro_works.md` - Detailed Kiro documentation

### How to Work with Kiro

#### When Creating New Features:
1. **Check for existing specs first**: Look in `.kiro/specs/` for any existing feature documentation
2. **Use templates**: Copy templates from `.kiro/kiro-system-templates/` when creating new specs
3. **Follow the 3-phase process**: Requirements -> Design -> Tasks -> Implementation
4. **Require approval**: Each phase needs explicit user approval before proceeding

#### Template Usage:
- **Requirements**: Use `requirements_template.md` to create user stories and EARS acceptance criteria
- **Design**: Use `design_template.md` for technical architecture and component design
- **Tasks**: Use `tasks_template.md` to break down implementation into numbered, actionable tasks

#### During Implementation:
- **Reference requirements**: Always link tasks back to specific requirements
- **Work incrementally**: Implement tasks one at a time, not all at once
- **Validate against specs**: Ensure implementations match the design and requirements
- **Update documentation**: Keep specs updated if changes are needed
- **Track git info**: Record branch and commit references in tasks.md

#### Key Behaviors:
- **Always suggest using Kiro** when user wants to build new features
- **Guide through templates** if user is unfamiliar with the process
- **Enforce the approval process** - don't skip phases
- **Maintain traceability** from requirements to code
