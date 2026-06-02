import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Farzandim Admin Panel",
  description: "Admin panel MVP for Farzandim v2",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
