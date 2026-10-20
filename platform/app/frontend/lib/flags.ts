// FeatureFlag::GROUPS (app/models/feature_flag.rb): the groups a flag can be turned on for.
export type FlagGroups = Record<string, { label: string; description: string }>

// Admin::FlagsController#user_matches: people to turn a flag on for.
export type UserMatch = { id: string; name: string; avatar: string; email: string }

// How code checks a flag, for copying.
export function flagUsage(key: string) {
  return `Flipper.enabled?(:${key}, current_user)`
}
