import { api } from "./api";
import type { DashboardStats } from "@/types/admin";

export const getDashboardStats = async () => {
  const res = await api.get<DashboardStats>("/admin/dashboard");
  return res.data;
};
