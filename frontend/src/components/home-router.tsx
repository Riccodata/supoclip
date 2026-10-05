"use client";

import { useEffect } from "react";
import dynamic from "next/dynamic";
import { useRouter } from "next/navigation";

import LandingPage from "@/components/landing-page";
import { useSession } from "@/lib/auth-client";
import { isLandingOnlyModeEnabled, isPrivateModeEnabled } from "@/lib/app-flags";

const HomeApp = dynamic(() => import("@/components/home-app"), {
  ssr: false,
});

export function HomeRouter() {
  const { data: session, isPending } = useSession();
  const router = useRouter();
  const sendToSignIn = isPrivateModeEnabled && !isPending && !session?.user;

  useEffect(() => {
    if (sendToSignIn) {
      router.replace("/sign-in");
    }
  }, [sendToSignIn, router]);

  if (!isLandingOnlyModeEnabled && !isPending && session?.user) {
    return <HomeApp />;
  }

  if (isPrivateModeEnabled) {
    return null;
  }

  return <LandingPage />;
}
