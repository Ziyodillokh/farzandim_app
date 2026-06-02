import { api } from "./api";
import type { Child } from "@/types/admin";

export const getChildren = async () => {
  const res = await api.get<Child[]>("/admin/children");
  return res.data;
};
