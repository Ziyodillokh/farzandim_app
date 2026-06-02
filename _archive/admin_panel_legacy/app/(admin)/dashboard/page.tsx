"use client";

import { useEffect, useState } from "react";
import { getDashboardStats } from "@/services/dashboard.service";
import type { DashboardStats } from "@/types/admin";

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadStats = async () => {
      try {
        setLoading(true);
        const data = await getDashboardStats();
        setStats(data);
      } catch (e) {
        console.error(e);
        setError("Failed to load dashboard stats.");
      } finally {
        setLoading(false);
      }
    };

    void loadStats();
  }, []);

  if (loading) {
    return (
      <section className="space-y-6">
        <h1 className="text-2xl font-semibold text-slate-900">Farzandim Admin Panel</h1>
        <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm text-slate-500">
          Loading dashboard...
        </div>
      </section>
    );
  }

  if (error) {
    return (
      <section className="space-y-6">
        <h1 className="text-2xl font-semibold text-slate-900">Farzandim Admin Panel</h1>
        <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700">
          {error}
        </div>
      </section>
    );
  }

  if (!stats) {
    return (
      <section className="space-y-6">
        <h1 className="text-2xl font-semibold text-slate-900">Farzandim Admin Panel</h1>
        <div className="rounded-xl border border-slate-200 bg-white p-6 text-slate-500 shadow-sm">
          No dashboard data available.
        </div>
      </section>
    );
  }

  const statCards = [
    { label: "Total Parents", value: stats.totalParents },
    { label: "Total Children", value: stats.totalChildren },
    { label: "Active Subscriptions", value: stats.activeSubscriptions },
  ];

  return (
    <section className="space-y-6">
      <h1 className="text-2xl font-semibold text-slate-900">Farzandim Admin Panel</h1>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {statCards.map((card) => (
          <div
            key={card.label}
            className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm"
          >
            <p className="text-sm text-slate-500">{card.label}</p>
            <p className="mt-2 text-3xl font-bold text-slate-900">{card.value}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
