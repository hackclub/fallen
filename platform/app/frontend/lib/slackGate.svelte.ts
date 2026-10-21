import { page } from '@inertiajs/svelte'
import { shared } from '@/lib/shared.svelte'
import { tour } from '@/lib/tour.svelte'

// Someone who started with just an email signs in with Hack Club Auth first, which keeps their pet and project
// (User.from_hca_code!). After the onboarding, Slack: journals are posted as the person, so until it is connected
// or skipped there is nothing else to do. The server only asks for either when it applies (ApplicationController#setup_props).
// A project's own pages are let through: the onboarding ends on one, and they explain Slack in place. So are the
// docs, for someone just reading them, and a team's join link and invite, which come before any of it.
const OPEN_PAGES = ['Projects/Show', 'Projects/Form', 'Docs/Show', 'ProjectJoins/Show', 'ProjectInvites/Show']

// Whether components/onboarding/SlackGate.svelte is up. The layout keeps its nav rail above it so the open pages
// stay a click away, and the desktop pet stays out of the way.
export function slackGateDue() {
  const step = shared().setup?.step
  return (step === 'slack' || step === 'verify') && !tour.open && !OPEN_PAGES.includes(page.component)
}
