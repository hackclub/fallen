// Firefox has no per-element layers: a moving element is redrawn every frame, and every blur, filter, mask, 3D
// transform or rounded clip on it is paid for again each time. The landing page's wheel swaps those for cheaper
// drawings there; the `firefox:` variant in application.css is the same test in CSS.
export const firefox = typeof CSS !== 'undefined' && CSS.supports('-moz-appearance', 'none')
