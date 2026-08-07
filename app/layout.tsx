import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Sigap Helpdesk",
  description: "Pusat layanan bantuan dan manajemen tiket",
  icons: { icon: "/branding/favicon.ico" },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="id"><body>{children}</body></html>;
}
