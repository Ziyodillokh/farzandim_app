import { api } from "./api";
import type { Parent } from "@/types/admin";

export const getParents = async () => {
  const res = await api.get<Parent[]>("/admin/parents");
  return res.data;
};
