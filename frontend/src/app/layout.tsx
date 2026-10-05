import type { Metadata } from "next";
import { Geist, Geist_Mono, Syne } from "next/font/google";
import Script from "next/script";
import "./globals.css";
import { DataFastIdentity } from "@/components/datafast-identity";
import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { FeedbackButton } from "@/components/feedback-button";
import { isPrivateModeEnabled } from "@/lib/app-flags";
import { APP_STORE_ID, SITE_NAME, getSiteUrl } from "@/lib/site";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const syne = Syne({
  variable: "--font-syne",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
});

const dataFastWebsiteId = process.env.NEXT_PUBLIC_DATAFAST_WEBSITE_ID;
const dataFastDomain = process.env.NEXT_PUBLIC_DATAFAST_DOMAIN;
const shouldTrackLocalhost = process.env.NEXT_PUBLIC_DATAFAST_ALLOW_LOCALHOST === "true";
const isDataFastEnabled = Boolean(dataFastWebsiteId && dataFastDomain);

export const metadata: Metadata = {
  title: {
    default: `${SITE_NAME} – Open-Source AI Video Clipper`,
    template: `%s | ${SITE_NAME}`,
  },
  description:
    "Turn long videos into captioned short-form clips with open-source AI clipping, virality scoring, and face-aware vertical crops.",
  metadataBase: new URL(getSiteUrl()),
  applicationName: SITE_NAME,
  authors: [{ name: `${SITE_NAME} Team`, url: getSiteUrl() }],
  creator: `${SITE_NAME} Team`,
  publisher: SITE_NAME,
  category: "video software",
  icons: {
    icon: "/icon.png",
  },
  // The iOS Smart App Banner points at the official SupoClip app.
  ...(isPrivateModeEnabled ? {} : { itunes: { appId: APP_STORE_ID } }),
  openGraph: {
    title: `${SITE_NAME} – Open-Source AI Video Clipper`,
    description:
      "Turn long videos into captioned short-form clips with open-source AI clipping.",
    siteName: SITE_NAME,
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: `${SITE_NAME} – Open-Source AI Video Clipper`,
    description:
      "Open-source AI clipping, virality scoring, captions, and face-aware vertical crops.",
  },
  robots: {
    index: !isPrivateModeEnabled,
    follow: !isPrivateModeEnabled,
    googleBot: {
      index: !isPrivateModeEnabled,
      follow: !isPrivateModeEnabled,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        {isDataFastEnabled ? (
          <>
            <Script id="datafast-queue" strategy="beforeInteractive">
              {`window.datafast = window.datafast || function() {
  window.datafast.q = window.datafast.q || [];
  window.datafast.q.push(arguments);
};`}
            </Script>
            <Script
              id="datafast-script"
              strategy="afterInteractive"
              src="/js/script.js"
              data-website-id={dataFastWebsiteId}
              data-domain={dataFastDomain}
              data-allow-localhost={shouldTrackLocalhost ? "true" : undefined}
              data-disable-console="true"
            />
          </>
        ) : null}
      </head>
      <body className={`${geistSans.variable} ${geistMono.variable} ${syne.variable} antialiased`}>
        <TooltipProvider>
          {children}
          <DataFastIdentity />
          <FeedbackButton />
          <Toaster />
        </TooltipProvider>
      </body>
    </html>
  );
}
