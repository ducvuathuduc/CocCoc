import { Account, Client } from 'node-appwrite';
export function createAccountVerifier(endpoint: string, project: string) {
  if (!endpoint.startsWith('https://') || !project) throw new Error('INVALID_AUTH_CONFIGURATION');
  return async (jwt: string): Promise<string> => {
    if (!jwt || jwt.length > 8192) throw new Error('AUTH_REQUIRED');
    const client = new Client().setEndpoint(endpoint).setProject(project).setJWT(jwt);
    const user = await new Account(client).get();
    return user.$id;
  };
}
