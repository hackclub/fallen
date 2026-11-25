# The sign-off desk and the copy checker live in the private hackclub/fallen-desk repo, mounted at vendor/desk (a git
# submodule). Without it Fallen runs as before: no copy checks, and /admin/sign-offs is the plain list.
Dir[Rails.root.join("vendor/desk/lib/*.rb")].each { require it }
