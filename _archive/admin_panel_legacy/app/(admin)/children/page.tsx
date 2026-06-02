"use client";

import { useEffect, useState } from "react";
import { getChildren } from "@/services/children.service";
import type { Child } from "@/types/admin";

export default function ChildrenPage() {
  const [children, setChildren] = useState<Child[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadChildren = async () => {
      try {
        setLoading(true);
        const data = await getChildren();
        setChildren(data);
      } catch (e) {
        console.error(e);
        setError("Failed to load children.");
      } finally {
        setLoading(false);
      }
    };

    void loadChildren();
  }, []);

  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-semibold text-slate-900">Children</h1>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-sm">
        {loading ? (
          <div className="p-6 text-slate-500">Loading children...</div>
        ) : error ? (
          <div className="p-6 text-red-700 bg-red-50 border-b border-red-200">{error}</div>
        ) : children.length === 0 ? (
          <div className="p-6 text-slate-500">No children found.</div>
        ) : null}

        <table className="min-w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-600">
            <tr>
              <th className="px-4 py-3 font-medium">Child name</th>
              <th className="px-4 py-3 font-medium">Parent name</th>
              <th className="px-4 py-3 font-medium">Age</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {children.map((child) => (
              <tr key={child.id} className="border-t border-slate-100">
                <td className="px-4 py-3">{child.name}</td>
                <td className="px-4 py-3">{child.parentName}</td>
                <td className="px-4 py-3">{child.age}</td>
                <td className="px-4 py-3">
                  <span
                    className={`rounded-full px-2 py-1 text-xs font-medium ${
                      child.status === "active"
                        ? "bg-green-100 text-green-700"
                        : "bg-slate-200 text-slate-700"
                    }`}
                  >
                    {child.status}
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
