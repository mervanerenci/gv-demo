import React, { createContext, useContext, useState, useEffect } from 'react';
import { AuthClient } from '@dfinity/auth-client';
import { canisterId } from '../declarations/backend';
import { HttpAgent } from '@dfinity/agent';
import { createActor } from '../declarations/backend';


interface AuthContextType {
  isAuthenticated: boolean;
  login: () => Promise<void>;
  logout: () => Promise<void>;
  authClient: AuthClient | null;
  backendActor: any;
  principal: string | null;
}

const AuthContext = createContext<AuthContextType | null>(null);

let backendActor: any;
export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authClient, setAuthClient] = useState<AuthClient | null>(null);
  const [principal, setPrincipal] = useState<string | null>(null);

  const ii_canister_id = 'be2us-64aaa-aaaaa-qaabq-cai';
  useEffect(() => {
    AuthClient.create().then(async (client) => {
      setAuthClient(client);
      const isAuth = await client.isAuthenticated();
      setIsAuthenticated(isAuth);
    });
  }, []);

  const login = async () => {
    
    
    const identityProvider = process.env.DFX_NETWORK === 'ic' 
      ? 'https://identity.ic0.app'
      : `http://${ii_canister_id}.localhost:4943`;
    
      
        // create an auth client
        let authClient = await AuthClient.create();
    
        // start the login process and wait for it to finish
        await new Promise((resolve) => {
            authClient.login({
                identityProvider: `http://${ii_canister_id}.localhost:4943`,
                onSuccess: resolve,
            });
        });

        const identity = authClient.getIdentity();
        const principal = identity.getPrincipal();
        setPrincipal(principal.toString());
    
        // Using the identity obtained from the auth client, we can create an agent to interact with the IC.
        const agent = new HttpAgent({identity});
        // Using the interface description of our webapp, we create an actor that we use to call the service methods.
        backendActor = createActor(canisterId, {
            agent,
        });

        setIsAuthenticated(true);
        console.log("logged in principal", principal);
        return backendActor;
      
    
    
  };

  const logout = async () => {
    if (!authClient) return;
    await authClient.logout();
    setIsAuthenticated(false);
  };

  return (
    <AuthContext.Provider value={{ isAuthenticated, login, logout, authClient, backendActor, principal }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}; 