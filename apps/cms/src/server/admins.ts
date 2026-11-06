import { config } from './config';

export interface AdminIdentity {
  userId: string;
  email: string;
  name: string;
}

/** The whole access rule: an Appwrite account opens the CMS only if its userId is listed. */
export function isAdmin(identity: AdminIdentity): boolean {
  return config().admins.has(identity.userId);
}
