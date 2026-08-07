"use client";
import { FormEvent, useState } from "react";
import { Mail, Lock, ArrowRight, Loader2 } from "lucide-react";
import { createSupabaseBrowserClient } from "@/lib/supabase-browser";

export default function LoginPage() {
  const [email, setEmail] = useState(""); const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false); const [message, setMessage] = useState("");
  async function submit(event: FormEvent) {
    event.preventDefault(); setLoading(true); setMessage("");
    const supabase = createSupabaseBrowserClient();
    if (!supabase) { setMessage("Konfigurasi Supabase belum terbaca. Periksa .env.local."); setLoading(false); return; }
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setMessage(error.message === "Invalid login credentials" ? "Email atau kata sandi salah." : error.message);
    else window.location.href = "/";
    setLoading(false);
  }
  return <main className="auth-shell"><section className="auth-card"><div className="auth-brand"><img src="/branding/sigap-logo.png" alt="Sigap"/><div><strong>Sigap</strong><span>Helpdesk</span></div></div><h1>Selamat datang kembali</h1><p className="auth-sub">Masuk untuk mengelola layanan dan tiket Anda.</p><form onSubmit={submit}><label>Email<input required type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="nama@contoh.com"/><Mail size={16}/></label><label>Kata sandi<input required minLength={6} type="password" value={password} onChange={e=>setPassword(e.target.value)} placeholder="Masukkan kata sandi"/><Lock size={16}/></label><button className="primary auth-submit" disabled={loading}>{loading?<Loader2 className="spin" size={17}/>:<ArrowRight size={17}/>} Masuk</button>{message&&<p className="auth-error">{message}</p>}</form><p className="auth-help">Belum punya akun? Hubungi administrator untuk mendapatkan akses.</p></section></main>;
}
