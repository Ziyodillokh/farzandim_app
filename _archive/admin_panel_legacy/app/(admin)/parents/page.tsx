"use client";

import { useEffect, useState } from "react";
import { getParents } from "@/services/parents.service";
import type { Parent } from "@/types/admin";

export default function ParentsPage() {
  const [parents, setParents] = useState<Parent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadParents = async () => {
      try {
        setLoading(true);
        const data = await getParents();
        setParents(data);
      } catch (e) {
        console.error(e);
        setError("Failed to load parents.");
      } finally {
        setLoading(false);
      }
    };

    void loadParents();
  }, []);

  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-semibold text-slate-900">Parents</h1>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-sm">
        {loading ? (
          <div className="p-6 text-slate-500">Loading parents...</div>
        ) : error ? (
          <div className="p-6 text-red-700 bg-red-50 border-b border-red-200">{error}</div>
        ) : parents.length === 0 ? (
          <div className="p-6 text-slate-500">No parents found.</div>
        ) : null}

        <table className="min-w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-600">
            <tr>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Phone</th>
              <th className="px-4 py-3 font-medium">Created date</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {parents.map((parent) => (
              <tr key={parent.id} className="border-t border-slate-100">
                <td className="px-4 py-3">{parent.name}</td>
                <td className="px-4 py-3">{parent.phone}</td>
                <td className="px-4 py-3">{parent.createdDate ?? parent.createdAt ?? "-"}</td>
                <td className="px-4 py-3">
                  <span
                    className={`rounded-full px-2 py-1 text-xs font-medium ${
                      parent.status === "active"
                        ? "bg-green-100 text-green-700"
                        : "bg-slate-200 text-slate-700"
                    }`}
                  >
                    {parent.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
