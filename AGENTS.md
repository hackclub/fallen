# Working on this repo

- `platform/` is the Rails app. Its conventions are in `platform/AGENTS.md`; read that before changing anything in
  it. Run `bin/rails`, `bundle` and `npm` from inside it, and `bin/ci` before you finish.
- `program/` is Markdown about the program itself. `program/the-plan.md` has the current plan; it is rough and the
  numbers will change, so don't build features that hard-code them without asking.
- Keep the root minimal. A second app gets its own top-level folder.
