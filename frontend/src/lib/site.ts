// Self-hosted deployments can rebrand the app with NEXT_PUBLIC_SITE_NAME (build time).
export const SITE_NAME = process.env.NEXT_PUBLIC_SITE_NAME || "SupoClip";
export const DEFAULT_SITE_URL = "https://www.supoclip.com";
export const HOSTED_APP_URL = DEFAULT_SITE_URL;
export const GITHUB_URL = "https://github.com/FujiwaraChoki/supoclip";
export const APP_STORE_ID = "6784760040";
export const APP_STORE_URL = `https://apps.apple.com/us/app/supoclip/id${APP_STORE_ID}`;

export function getSiteUrl() {
  try {
    return new URL(process.env.NEXT_PUBLIC_APP_URL || DEFAULT_SITE_URL).origin;
  } catch {
    return DEFAULT_SITE_URL;
  }
}
