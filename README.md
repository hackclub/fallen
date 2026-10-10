<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/wordmark-dark.png">
  <img src=".github/wordmark-light.png" width="400" alt="Fallen">
</picture>

fall fall fallen

- [`platform/`](platform/) is the app. Setup is in [`platform/README.md`](platform/README.md).
- [`program/`](program/) is everything else about the program.

## Local development

```sh
mise install
cd platform
docker compose up -d db
bin/setup
```
