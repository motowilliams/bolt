## Title

Split package starters into docker and non-docker supported packages.

## Summary

Split starters so each package either uses local toolchains or docker only. This removes the mixed fallback logic that makes starter tasks verbose.

## Description

We have an issue where every time that callback is executed the base image invokes adding any necessary dependencies and then executing the command(s) required by that container.

In the end we will have the following starter packages:

- .build-bicep
- .build-dotnet
- .build-dotnet-docker
- .build-golang
- .build-golang-docker
- .build-python
- .build-python-docker
- .build-terraform
- .build-terraform-docker
- .build-typescript
- .build-typescript-docker

Note that bicep does not have a vendor or official project supported docker container.

## Decisions

- Replace docker fallback behavior with dedicated *-docker starters.
- Each *-docker starter ships with a sibling Dockerfile used by its tasks.
- Docker image rebuilds are controlled by tool-specific environment variables per starter.
- On Windows, docker-only starters require Linux containers.

## Implementation Outline

- Split existing starters into non-docker and docker-only variants.
- Remove docker fallback logic from non-docker starters.
- Non-docker starters should have zero references to docker.
- Non-docker do not need to implement any fall back patterns
- Add per-starter Dockerfiles for docker-only starters and reference them from task scripts.
- Add documented, tool-specific env vars to force docker image rebuilds.
- Update Invoke-Tests.ps1 to have tags for the new set of tests
- update create-package-starter.prompt.md to handle creating future non-docker and docker supported packages
- update CONTRIBUTING.MD as well so that any forks pull requests know we now have a split pattern for non-docker and docker packages
- Update CHANGELOG.md with a new minor version

## Documentation Impact

- Update packages overview in [packages/README.md](packages/README.md).
- Update ecosystem docs in [docs/ecosystem.md](docs/ecosystem.md).
- Update implementation notes that describe docker fallback in [IMPLEMENTATION.md](IMPLEMENTATION.md).

## Agent Checklist

- Inventory existing starters and identify docker fallback logic to remove.
- Copy existing starters as the new *-docker starter folders with required task scripts, README, tests, and Dockerfile.
- Update non-docker starters to use local toolchains only (no docker fallback).
- No dockers references should remain in the non-docker starter packages
- Implement tool-specific env vars to force docker image rebuilds in each docker starter.
- Ensure Windows guidance calls out Linux containers requirement for docker starters.
- Update docs listed in Documentation Impact to reflect the split.
