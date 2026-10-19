// The <meta> CSRF token goes stale once sign-in resets the session, since Inertia never re-renders it.
// inertia_rails keeps the XSRF-TOKEN cookie current, so read that first.
export function csrfToken() {
  const cookie = document.cookie.match(/(?:^|; )XSRF-TOKEN=([^;]*)/)?.[1]
  return cookie
    ? decodeURIComponent(cookie)
    : (document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? '')
}
