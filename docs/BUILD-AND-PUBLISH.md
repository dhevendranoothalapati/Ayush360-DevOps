# Ayush360 Backend Build and Publish Flow

This document explains how the backend Docker images are built, published, versioned, and rolled out. It also captures the release-tag rule that prevents tags from being created when a build fails.

## 1. What gets built

The backend workflow builds four images from the same repository:

- `ayush360-identity` — built from `Dockerfile --target identity`
- `ayush360-hms` — built from `Dockerfile --target hms`
- `ayush360-migrator` — built from `Dockerfile --target migrator`
- `ayush360-web` — built from the frontend repo and published separately

Each image has a different runtime responsibility:

- `identity` signs JWTs and manages auth
- `hms` serves the hospital APIs and business logic
- `migrator` performs schema migrations once per release
- `web` is the public UI and API gateway surface

## 2. GitHub Actions flow

The workflow does this in order:

1. `prepare-release`
   - calculates the next version tag, for example `v0.1.0`, `v0.1.1`, etc.
   - does not create a Git tag yet
2. `backend-images`
   - logs in to GHCR
   - normalizes the owner name to lowercase
   - builds and pushes all backend images for the computed version
   - also pushes `:latest` tags
3. `tag-release`
   - runs only when the `backend-images` job succeeds
   - creates the Git tag and pushes it to origin

This is the important change: the tag is created only after the image publish succeeds. If the build or push fails, no Git tag is created.

## 3. Why three backend images are normal

Three backend images are okay and recommended for this project because they serve three different runtime roles:

- `identity` and `hms` are long-running services and are started independently
- `migrator` is a one-off job that must run before the API containers come up
- each service can be updated and restarted separately without rebuilding or redeploying the whole stack

This gives better operational clarity than trying to pack everything into one container.

## 4. Per-service versioning

The recommended pattern is to track a version per service, even when they are released together as a single deployment window.

Example:

```env
APP_VERSION=v1.2.3
IDENTITY_IMAGE_TAG=v1.2.3
HMS_IMAGE_TAG=v1.2.4
MIGRATOR_IMAGE_TAG=v1.2.5
WEB_IMAGE_TAG=v1.2.6
```

This is useful when:

- the frontend and backend are rebuilt at different times
- one service gets a hotfix while another remains on the previous version
- the migration job is intentionally kept on a different release cadence

The service-specific value is the one that should be used in the container image tag; `APP_VERSION` remains a stable fallback/default when no override is provided.

## 5. Optimization recommendations

The current matrix approach is reasonable for a small backend monorepo. A few optimizations are still worth adding:

### A. Build cache

The workflow already uses GitHub Actions cache (`cache-from` / `cache-to`) to reduce rebuild time.

### B. Trigger only on backend changes

Use path filters so the backend workflow runs only when relevant files change:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'Dockerfile'
      - '.github/workflows/backend-docker.yml'
```

This prevents unnecessary builds on unrelated repo changes.

### C. Optional: only build changed service(s)

If the project grows larger, add a path-aware matrix that skips unchanged services. For example:

- only rebuild `identity` when `src/Ayush360.Identity.Api/**` changes
- only rebuild `hms` when `src/Ayush360.Hms.Api/**` changes
- only rebuild `migrator` when migration files change

### D. Keep service boundaries

Do not collapse the three backend images into one container unless the runtime responsibilities are merged. That would make schema migrations, auth, and API runtime harder to manage and harder to roll back safely.

## 6. Example release tag policy

The image tags should be generated as service-specific values, for example:

```text
ghcr.io/<owner>/ayush360-identity:v1.2.3
ghcr.io/<owner>/ayush360-hms:v1.2.4
ghcr.io/<owner>/ayush360-migrator:v1.2.5
ghcr.io/<owner>/ayush360-web:v1.2.6
```

The matching Git tag remains a release marker for the overall deployment run, but the container images can be updated independently when needed.

## 7. Best practice

For production, keep the following rule:

- build and push images
- run migrator
- wait for success
- swap the app containers
- only then create the release tag if the entire release is healthy

This keeps the Git tags as an auditable marker of a completed successful release rather than a partial or failed deployment.
