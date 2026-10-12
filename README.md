<div align="center"> 
  
<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/wordmark-dark.png">
  <img src=".github/wordmark-light.png" width="400" alt="Fallen">
</picture>

### A 4-day hardware adventure in Shenzhen, China!

</div>

<hr>

- [`platform/`](platform/) is the main app & setup instructions are in [`platform/README.md`](platform/README.md).
- [`program/`](program/) breaks down how we're organizing this event!

## Local development

```sh
mise install
cd platform
docker compose up -d db
bin/setup
```
