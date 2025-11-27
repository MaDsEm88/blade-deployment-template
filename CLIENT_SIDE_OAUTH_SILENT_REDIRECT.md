# Client-Side OAuth with Silent Redirect

## Overview

This guide explains how to implement OAuth authentication using a **client-side silent redirect pattern**. Unlike traditional OAuth flows that navigate users through separate callback and verification pages, this approach keeps the user on the home page while handling all OAuth operations silently in the background.

### Key Characteristics

- 👤 **User stays on homepage** - No page navigation during auth
- 🔗 **URL updates** - Shows user handle (e.g., `localhost:3000/mark-madsen`)
- 🔐 **Silent token exchange** - Callback processing happens in background
- 🚀 **Seamless UX** - Single page application feel for authentication

## Architecture Comparison

### Traditional OAuth Flow (Current Approach)
```
User → [Home] → [OAuth Provider] → [Callback Page] → [Verify Page] → [Home with Auth]
```

Pages navigate sequentially, users see intermediate pages.

### Silent Redirect Flow (This Approach)
```
User → [Home - shows spinner/loading] 
  ↓ (background processing)
OAuth Provider ↔ Home (receives callback via search params)
  ↓ (silent token exchange)
URL updates to /username → User stays on Home [Authenticated]
```

Single page, OAuth happens in background, only URL changes.

## Implementation Guide

### 1. OAuth Provider Configuration

Configure your OAuth provider (GitHub, Google, etc.) with:

**Redirect URI**: `https://your-app.com` (or `http://localhost:3000` for development)

**Important**: The redirect URI should point to your **home page**, not a separate callback page.

### 2. Setup Environment Variables

```bash
# In .env or deployment platform
VITE_OAUTH_PROVIDER_ID=your_oauth_provider_id
VITE_OAUTH_CLIENT_ID=your_client_id
VITE_OAUTH_REDIRECT_URI=https://your-app.com  # or http://localhost:3000 for dev

# Keep this secret (backend only)
OAUTH_CLIENT_SECRET=your_client_secret
BLADE_PUBLIC_URL=https://your-app.com
```

### 3. Create OAuth Hook

Create a custom React hook to handle the entire OAuth flow:

```typescript
// hooks/useOAuth.ts
import { useEffect, useState, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom'; // or your routing library

interface OAuthState {
  isAuthenticating: boolean;
  isAuthenticated: boolean;
  user: { handle: string; id: string } | null;
  error: string | null;
}

export function useOAuth() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [state, setState] = useState<OAuthState>({
    isAuthenticating: false,
    isAuthenticated: false,
    user: null,
    error: null
  });

  // Handle incoming OAuth callback
  useEffect(() => {
    const code = searchParams.get('code');
    const state_param = searchParams.get('state');
    const error = searchParams.get('error');

    if (error) {
      setState(prev => ({ ...prev, error }));
      return;
    }

    if (!code) return;

    // Verify state parameter for security
    const storedState = sessionStorage.getItem('oauth_state');
    if (state_param !== storedState) {
      setState(prev => ({ ...prev, error: 'State mismatch - possible CSRF attack' }));
      return;
    }

    // Start authentication
    handleOAuthCallback(code);
  }, [searchParams]);

  const handleOAuthCallback = useCallback(async (code: string) => {
    try {
      setState(prev => ({ ...prev, isAuthenticating: true, error: null }));

      // Exchange code for token (backend endpoint)
      const response = await fetch('/api/oauth/exchange', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code })
      });

      if (!response.ok) {
        throw new Error(`OAuth exchange failed: ${response.statusText}`);
      }

      const { user, token } = await response.json();

      // Store session token
      localStorage.setItem('auth_token', token);

      // Update URL silently without navigation
      const newUrl = `/${user.handle}`;
      window.history.replaceState(null, '', newUrl);

      setState(prev => ({
        ...prev,
        isAuthenticating: false,
        isAuthenticated: true,
        user
      }));

      // Clean up search params
      setSearchParams({});
      sessionStorage.removeItem('oauth_state');
    } catch (err) {
      setState(prev => ({
        ...prev,
        isAuthenticating: false,
        error: err instanceof Error ? err.message : 'Authentication failed'
      }));
    }
  }, [setSearchParams]);

  const initiateOAuth = useCallback(() => {
    // Generate state parameter for CSRF protection
    const state = Math.random().toString(36).substring(7);
    sessionStorage.setItem('oauth_state', state);

    // Build OAuth URL
    const params = new URLSearchParams({
      client_id: import.meta.env.VITE_OAUTH_CLIENT_ID,
      redirect_uri: import.meta.env.VITE_OAUTH_REDIRECT_URI,
      response_type: 'code',
      scope: 'user:email profile', // Adjust based on provider
      state
    });

    const oauthUrl = `https://oauth-provider.com/authorize?${params.toString()}`;
    
    // Navigate to OAuth provider - this is the only time user leaves the page
    window.location.href = oauthUrl;
  }, []);

  return {
    ...state,
    initiateOAuth
  };
}
```

### 4. Update Home Page Component

Modify your home page to handle OAuth:

```typescript
// pages/index.tsx
import { useOAuth } from '../hooks/useOAuth';
import { useEffect } from 'react';

export default function Home() {
  const { isAuthenticating, isAuthenticated, user, error, initiateOAuth } = useOAuth();

  if (isAuthenticating) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem' }}>
        <h1>Authenticating...</h1>
        <div className="spinner">Loading</div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem', color: 'red' }}>
        <h1>Authentication Error</h1>
        <p>{error}</p>
        <button onClick={initiateOAuth}>Try Again</button>
      </div>
    );
  }

  if (isAuthenticated && user) {
    return (
      <div style={{ maxWidth: '800px', margin: '0 auto', padding: '2rem' }}>
        <h1>Welcome, {user.handle}!</h1>
        <p>You are authenticated.</p>
        <p>URL: {user.handle}</p>
        <button onClick={() => {
          localStorage.removeItem('auth_token');
          window.location.href = '/';
        }}>
          Logout
        </button>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto', padding: '2rem' }}>
      <h1>Welcome to My App</h1>
      <p>Sign in with your account to continue.</p>
      <button 
        onClick={initiateOAuth}
        style={{ padding: '0.5rem 1rem', fontSize: '1rem' }}
      >
        Sign In with OAuth
      </button>
    </div>
  );
}
```

### 5. Backend OAuth Exchange Endpoint

Create an API endpoint to handle token exchange:

```typescript
// This would be your backend (e.g., Express, Blade API route, etc.)
// POST /api/oauth/exchange

import crypto from 'crypto';

export async function exchangeOAuthCode(code: string) {
  try {
    // Exchange authorization code for token
    const tokenResponse = await fetch('https://oauth-provider.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: process.env.VITE_OAUTH_CLIENT_ID,
        client_secret: process.env.OAUTH_CLIENT_SECRET,
        code,
        redirect_uri: process.env.VITE_OAUTH_REDIRECT_URI,
        grant_type: 'authorization_code'
      })
    });

    if (!tokenResponse.ok) {
      throw new Error('Token exchange failed');
    }

    const { access_token } = await tokenResponse.json();

    // Fetch user info from OAuth provider
    const userResponse = await fetch('https://oauth-provider.com/user', {
      headers: { Authorization: `Bearer ${access_token}` }
    });

    if (!userResponse.ok) {
      throw new Error('Failed to fetch user info');
    }

    const oauthUser = await userResponse.json();

    // Create or update user in your database
    const user = await createOrUpdateUser({
      id: oauthUser.id,
      handle: oauthUser.login || oauthUser.email.split('@')[0],
      email: oauthUser.email,
      avatar: oauthUser.avatar_url
    });

    // Create session token
    const sessionToken = crypto.randomBytes(32).toString('hex');
    await storeSessionToken(user.id, sessionToken);

    return {
      user: { id: user.id, handle: user.handle },
      token: sessionToken
    };
  } catch (error) {
    console.error('OAuth exchange error:', error);
    throw error;
  }
}
```

### 6. Handle Dynamic Routes

Once authenticated, handle the user's handle route:

```typescript
// pages/[handle].tsx (or equivalent for your router)

import { useParams, useNavigate } from 'react-router-dom'; // or your routing library
import { useEffect, useState } from 'react';

export default function UserPage() {
  const { handle } = useParams();
  const navigate = useNavigate();
  const [user, setUser] = useState(null);

  useEffect(() => {
    // Verify user is authenticated
    const token = localStorage.getItem('auth_token');
    if (!token) {
      navigate('/');
      return;
    }

    // Fetch user data
    fetchUserData(handle, token);
  }, [handle]);

  const fetchUserData = async (handle: string, token: string) => {
    try {
      const response = await fetch(`/api/users/${handle}`, {
        headers: { Authorization: `Bearer ${token}` }
      });

      if (!response.ok) throw new Error('User not found');
      const data = await response.json();
      setUser(data);
    } catch (error) {
      console.error('Failed to fetch user:', error);
      navigate('/');
    }
  };

  if (!user) return <div>Loading...</div>;

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto', padding: '2rem' }}>
      <h1>{user.handle}</h1>
      <p>Email: {user.email}</p>
      {/* Your user profile content */}
    </div>
  );
}
```

## Security Considerations

### 1. State Parameter (CSRF Protection)
Always include a state parameter and validate it:
```typescript
const state = crypto.randomBytes(16).toString('hex');
sessionStorage.setItem('oauth_state', state);
// Include in OAuth URL
// Validate in callback
```

### 2. Token Storage
- **Short-lived tokens**: Store in sessionStorage (cleared on browser close)
- **Long-lived tokens**: Use secure, httpOnly cookies (backend must set)
- **Never**: Store tokens in localStorage for sensitive operations

```typescript
// Secure approach - backend sets httpOnly cookie
// Frontend stores nothing
const response = await fetch('/api/oauth/exchange', { 
  method: 'POST',
  credentials: 'include', // Include cookies
  body: JSON.stringify({ code })
});
```

### 3. HTTPS in Production
- Always use HTTPS in production
- OAuth providers reject http redirect URIs except localhost

### 4. Code Verification
Only allow one use of authorization code:
```typescript
// Backend
const codeUsed = await checkCodeUsed(code);
if (codeUsed) {
  throw new Error('Authorization code already used');
}
markCodeAsUsed(code);
```

## URL Management

### Using History API

Update URL without page reload:

```typescript
// Replace current history entry
window.history.replaceState(null, '', `/${user.handle}`);

// Or push new entry
window.history.pushState(null, '', `/${user.handle}`);
```

### Considerations

- `replaceState`: Better for OAuth - doesn't create back button issues
- `pushState`: Creates history entry, user can go back
- Always update state after URL change
- Handle back button appropriately

## Testing

### Test Cases

1. **Successful Authentication**
   - User clicks login
   - Redirected to OAuth provider
   - Returns with code
   - Token exchange succeeds
   - URL updates to `/username`
   - User data displays

2. **Failed Token Exchange**
   - Show error message
   - Provide retry button
   - Log error for debugging

3. **CSRF Attack Prevention**
   - State mismatch detected
   - Request rejected
   - Error displayed to user

4. **Session Restoration**
   - User refreshes page
   - Token validated
   - User remains authenticated
   - Profile displays

### Example Test (Jest + React Testing Library)

```typescript
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import Home from './pages/index';

test('authenticates user silently', async () => {
  // Mock fetch for OAuth exchange
  global.fetch = jest.fn((url) => {
    if (url.includes('/api/oauth/exchange')) {
      return Promise.resolve({
        ok: true,
        json: () => Promise.resolve({
          user: { handle: 'testuser', id: '123' },
          token: 'session_token_123'
        })
      });
    }
  });

  render(<Home />);
  
  // Simulate OAuth callback
  window.location.search = '?code=auth_code_123&state=state_123';
  
  await waitFor(() => {
    expect(screen.getByText(/Welcome, testuser/i)).toBeInTheDocument();
  });

  expect(window.location.pathname).toBe('/testuser');
});
```

## Troubleshooting

### Issue: "State Mismatch" Error

**Cause**: State parameter validation failed

**Solution**:
```typescript
// Ensure state is stored and validated
const state = sessionStorage.getItem('oauth_state');
if (!state) {
  // State wasn't set during OAuth initiation
  console.error('Missing state parameter');
}
```

### Issue: Token Exchange Fails

**Cause**: OAuth provider rejected the code

**Solutions**:
1. Verify redirect URI matches OAuth provider config
2. Check client ID and secret
3. Ensure code hasn't expired (usually 10 minutes)
4. Check network connectivity to OAuth provider

```typescript
// Add retry with exponential backoff
async function exchangeWithRetry(code: string, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await exchangeOAuthCode(code);
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000));
    }
  }
}
```

### Issue: User Data Not Loading

**Cause**: Authentication token not being sent

**Solution**:
```typescript
// Always include token in requests
const response = await fetch(`/api/users/${handle}`, {
  headers: { 
    Authorization: `Bearer ${localStorage.getItem('auth_token')}`
  }
});
```

### Issue: URL Changes but User Not Authenticated

**Cause**: Session not properly created

**Solution**:
```typescript
// Backend: Always create session before responding
await db.sessions.create({
  userId: user.id,
  token: sessionToken,
  expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
});

return { user, token: sessionToken };
```

## Advanced Features

### 1. Remember Me

Extend session token expiry:

```typescript
// Backend
const expiryDays = rememberMe ? 30 : 7;
const expiresAt = new Date(Date.now() + expiryDays * 24 * 60 * 60 * 1000);
```

### 2. Multiple OAuth Providers

```typescript
// Support GitHub, Google, etc.
function getOAuthConfig(provider: 'github' | 'google') {
  const configs = {
    github: { ... },
    google: { ... }
  };
  return configs[provider];
}
```

### 3. Session Refresh

```typescript
// Auto-refresh expiring tokens
useEffect(() => {
  const interval = setInterval(async () => {
    const response = await fetch('/api/oauth/refresh', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` }
    });
    if (response.ok) {
      const { token: newToken } = await response.json();
      localStorage.setItem('auth_token', newToken);
    }
  }, 5 * 60 * 1000); // Every 5 minutes

  return () => clearInterval(interval);
}, []);
```

### 4. Logout

```typescript
async function logout() {
  await fetch('/api/oauth/logout', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` }
  });
  
  localStorage.removeItem('auth_token');
  window.history.replaceState(null, '', '/');
  // Reload to show unauthenticated UI
  window.location.reload();
}
```

## Migration Checklist

Moving from traditional OAuth to silent redirect:

- [ ] Configure OAuth provider with home page as redirect URI
- [ ] Create `useOAuth` hook
- [ ] Implement backend token exchange endpoint
- [ ] Update home page component
- [ ] Add dynamic route handler for user profiles
- [ ] Set up session token storage
- [ ] Test CSRF protection with state parameter
- [ ] Test token refresh mechanism
- [ ] Test logout flow
- [ ] Verify browser history behavior
- [ ] Test on production OAuth provider
- [ ] Add error handling and user feedback
- [ ] Set up monitoring/logging
- [ ] Update user documentation

## Performance Considerations

### 1. Lazy Loading

Load OAuth hook only when needed:
```typescript
const OAuthDialog = lazy(() => import('./OAuthDialog'));
```

### 2. Session Validation

Cache user session to avoid repeated fetches:
```typescript
const [session, setSession] = useState(null);

useEffect(() => {
  const cached = sessionStorage.getItem('user_session');
  if (cached) {
    setSession(JSON.parse(cached));
    return;
  }
  
  validateSession();
}, []);
```

### 3. Minimize Re-renders

Use appropriate React patterns:
```typescript
const OAuthContext = createContext();

// Wrap app with provider
<OAuthProvider>
  <App />
</OAuthProvider>

// Use in components
const { user, isAuthenticated } = useContext(OAuthContext);
```

## References

- [OAuth 2.0 Authorization Code Flow](https://tools.ietf.org/html/rfc6749#section-1.3.1)
- [PKCE (Proof Key for Code Exchange)](https://tools.ietf.org/html/rfc7636)
- [Web History API](https://developer.mozilla.org/en-US/docs/Web/API/History)
- [HTTP Only Cookies](https://owasp.org/www-community/attacks/csrf)

## Summary

This silent redirect OAuth pattern provides:

✅ Better user experience (stays on home page)
✅ Cleaner URL structure (shows user handle)
✅ More control over UI states
✅ Better error handling
✅ Seamless integration with modern SPAs
⚠️ Requires careful security consideration
⚠️ More backend coordination needed
⚠️ Browser state management complexity

Choose this pattern when:
- User experience is critical
- You want a single-page feel
- You have full control of backend
- Your OAuth provider supports flexible redirect URIs

Choose traditional flow when:
- Simplicity is prioritized
- Multi-page architecture fits better
- External authentication service
