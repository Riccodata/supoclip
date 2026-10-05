export const isLandingOnlyModeEnabled =
  process.env.NEXT_PUBLIC_LANDING_ONLY_MODE === "true";

// Team-only deployments: signed-out visitors go to sign-in instead of the
// marketing landing page, and search engines are asked not to index the app.
export const isPrivateModeEnabled =
  process.env.NEXT_PUBLIC_PRIVATE_MODE === "true";
