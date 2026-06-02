export type Parent = {
  id: number;
  name: string;
  phone: string;
  createdDate?: string;
  createdAt?: string;
  status: "active" | "inactive";
};

export type Child = {
  id: number;
  name: string;
  parentName: string;
  age: number;
  status: "active" | "inactive";
};

export type DashboardStats = {
  totalParents: number;
  totalChildren: number;
  activeSubscriptions: number;
};
