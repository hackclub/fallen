import { usePage } from '@inertiajs/svelte'
import type { SharedProps } from '@/types'

// Typed access to the props shared from ApplicationController#inertia_share. Reactive: call it inside $derived.
export function shared(): SharedProps {
  return usePage<SharedProps>().props
}
