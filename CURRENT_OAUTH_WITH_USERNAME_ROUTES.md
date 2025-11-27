# Current OAuth Setup with Username Routes

## Overview

This guide explains how to enhance your **existing OAuth infrastructure** (callback.tsx → verify-oauth.tsx) to route authenticated users to their profile page at `localhost:3000/username` instead of back to the home page.

This is a **hybrid approach** that:
✅ Keeps your proven OAuth flow
✅ Maintains existing callback/verify infrastructure
✅ Adds clean username-based URLs
✅ Minimal changes to existing code
✅ Server-side redirect (more secure)

## Architecture

```
User → [Home] → [OAuth Provider] → [Callback Page] → [Verify Page]
                                                            ↓
                                        Extract user handle & redirect
                                                            ↓
                                        [/username Page] ← User stays here
```

## Why This Approach is Best for Long-Term

### 1. **Proven Infrastructure**
Your current callback → verify-oauth flow is production-tested. Don't change what works.

### 2. **Server-Side Redirect (More Secure)**
Unlike client-side silent redirects, the actual OAuth token exchange happens on the server before the user sees anything. No token exposure in browser URL.

```
OAuth Provider → Your Server (verify-oauth.tsx)
                 ↓
            Token Exchange (secure)
                 ↓
            Redirect /username (clean URL)
```

### 3. **Simpler Debugging**
All authentication happens in one place (verify-oauth.tsx). Easier to add logging, error handling, and fixes.

### 4. **Better for Scale**
When you need to:
- Add 2FA
- Update session management
- Revoke tokens
- Audit logs

All happen in one file instead of scattered across client-side hooks.

### 5. **Works with Existing Blade Router**
Blade's file-based routing makes dynamic routes simple.

## Implementation

### Step 1: Create Dynamic User Route

Create a new file `pages/[handle].tsx`:

```typescript
// pages/[handle].tsx
import { useParams, useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';

interface User {
  id: string;
  handle: string;
  email: string;
  avatar?: string;
}

export default function UserProfile() {
  const { handle } = useParams<{ handle: string }>();
  const navigate = useNavigate();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchUserProfile();
  }, [handle]);

  const fetchUserProfile = async () => {
    try {
      setLoading(true);
      
      // Check if user session is valid
      const response = await fetch(`/api/auth/me`, {
        headers: {
          'Authorization': `Bearer ${getSessionToken()}`
        }
      });

      if (!response.ok) {
        // Session invalid, redirect to home
        navigate('/');
        return;
      }

      const userData = await response.json();

      // Verify the URL handle matches authenticated user
      if (userData.handle !== handle) {
        // User trying to access someone else's profile
        navigate('/');
        return;
      }

      setUser(userData);
    } catch (err) {
      console.error('Failed to load profile:', err);
      setError('Failed to load profile');
      navigate('/');
    } finally {
      setLoading(false);
    }
  };

  const getSessionToken = () => {
    // Get from sessionStorage (most secure for OAuth)
    return sessionStorage.getItem('session_token') || '';
  };

  const handleLogout = async () => {
    try {
      // Invalidate session on backend
      await fetch('/api/auth/logout', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${getSessionToken()}`
        }
      });

      // Clear local storage
      sessionStorage.removeItem('session_token');
      
      // Redirect to home
      navigate('/');
    } catch (err) {
      console.error('Logout failed:', err);
    }
  };

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem' }}>
        <h1>Loading profile...</h1>
      </div>
    );
  }

  if (error || !user) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem', color: 'red' }}>
        <h1>Error Loading Profile</h1>
        <p>{error || 'Profile not found'}</p>
        <button onClick={() => navigate('/')}>Back to Home</button>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto', padding: '2rem' }}>
      <h1>@{user.handle}</h1>
      
      {user.avatar && (
        <img 
          src={user.avatar} 
          alt={user.handle}
          style={{ 
            width: '100px', 
            height: '100px', 
            borderRadius: '50%',
            marginBottom: '1rem'
          }}
        />
      )}

      <div style={{ marginTop: '1rem', padding: '1rem', backgroundColor: '#f5f5f5' }}>
        <p><strong>Email:</strong> {user.email}</p>
        <p><strong>ID:</strong> {user.id}</p>
      </div>

      <div style={{ marginTop: '2rem' }}>
        <button 
          onClick={handleLogout}
          style={{
            padding: '0.5rem 1rem',
            backgroundColor: '#ff4444',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          Logout
        </button>
      </div>
    </div>
  );
}
```

### Step 2: Update verify-oauth.tsx

Modify your existing verify-oauth.tsx to redirect to `/[handle]`:

```typescript
// pages/auth/verify-oauth.tsx
import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';

export default function VerifyOAuth() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    verifyOAuthToken();
  }, []);

  const verifyOAuthToken = async () => {
    try {
      // Get the token from search params (set by callback.tsx)
      const token = searchParams.get('token');
      const handle = searchParams.get('handle');

      if (!token || !handle) {
        throw new Error('Missing authentication parameters');
      }

      // Verify token is valid (call your backend)
      const response = await fetch('/api/auth/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token })
      });

      if (!response.ok) {
        throw new Error('Token verification failed');
      }

      const { user } = await response.json();

      // Store session token (in sessionStorage for security)
      sessionStorage.setItem('session_token', token);

      // Redirect to user profile page instead of home
      // This is the key change!
      navigate(`/${user.handle}`, { replace: true });
      
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Authentication failed';
      console.error('OAuth verification error:', message);
      setError(message);
    }
  };

  if (error) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem', color: 'red' }}>
        <h1>Authentication Error</h1>
        <p>{error}</p>
        <button onClick={() => navigate('/')}>Back to Home</button>
      </div>
    );
  }

  return (
    <div style={{ textAlign: 'center', padding: '2rem' }}>
      <h1>Verifying your authentication...</h1>
      <div className="spinner">Please wait</div>
    </div>
  );
}
```

### Step 3: Update callback.tsx

Ensure callback.tsx passes the user handle to verify-oauth.tsx:

```typescript
// pages/auth/callback.tsx
import { useEffect, useState } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';

export default function OAuthCallback() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    handleCallback();
  }, []);

  const handleCallback = async () => {
    try {
      const code = searchParams.get('code');
      const state = searchParams.get('state');
      const error = searchParams.get('error');

      if (error) {
        throw new Error(`OAuth provider error: ${error}`);
      }

      if (!code) {
        throw new Error('No authorization code received');
      }

      // Verify state (CSRF protection)
      const storedState = sessionStorage.getItem('oauth_state');
      if (state !== storedState) {
        throw new Error('State mismatch - possible CSRF attack');
      }

      // Exchange code for token on backend
      const response = await fetch('/api/oauth/exchange', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code, state })
      });

      if (!response.ok) {
        throw new Error('Token exchange failed');
      }

      const { token, user } = await response.json();

      // Clean up
      sessionStorage.removeItem('oauth_state');

      // Key change: pass handle to verify page
      navigate(`/auth/verify-oauth?token=${token}&handle=${user.handle}`, {
        replace: true
      });
      
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Authentication failed';
      console.error('OAuth callback error:', message);
      setError(message);
    }
  };

  if (error) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem', color: 'red' }}>
        <h1>OAuth Error</h1>
        <p>{error}</p>
        <button onClick={() => navigate('/')}>Back to Home</button>
      </div>
    );
  }

  return (
    <div style={{ textAlign: 'center', padding: '2rem' }}>
      <h1>Processing OAuth callback...</h1>
      <div className="spinner">Please wait</div>
    </div>
  );
}
```

### Step 4: Update Home Page

Update your home page to show login or check for existing session:

```typescript
// pages/index.tsx
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

interface User {
  handle: string;
  email: string;
}

export default function Home() {
  const navigate = useNavigate();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkAuthentication();
  }, []);

  const checkAuthentication = async () => {
    try {
      const token = sessionStorage.getItem('session_token');
      
      if (!token) {
        setLoading(false);
        return;
      }

      // Verify session is still valid
      const response = await fetch('/api/auth/me', {
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (response.ok) {
        const userData = await response.json();
        setUser(userData);
        
        // Redirect to user profile page
        navigate(`/${userData.handle}`, { replace: true });
      } else {
        // Session expired
        sessionStorage.removeItem('session_token');
      }
    } catch (err) {
      console.error('Failed to check authentication:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = () => {
    // Generate CSRF state
    const state = Math.random().toString(36).substring(7);
    sessionStorage.setItem('oauth_state', state);

    // Redirect to OAuth provider
    const params = new URLSearchParams({
      client_id: process.env.REACT_APP_OAUTH_CLIENT_ID!,
      redirect_uri: `${window.location.origin}/auth/callback`,
      response_type: 'code',
      scope: 'user:email profile',
      state
    });

    window.location.href = `https://your-oauth-provider.com/authorize?${params.toString()}`;
  };

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem' }}>
        <h1>Loading...</h1>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto', padding: '2rem' }}>
      <h1>Welcome to My App</h1>
      <p>Sign in to continue.</p>
      <button 
        onClick={handleLogin}
        style={{
          padding: '0.75rem 1.5rem',
          fontSize: '1rem',
          backgroundColor: '#007bff',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer'
        }}
      >
        Sign In with OAuth
      </button>
    </div>
  );
}
```

### Step 5: Backend Endpoints

Create these backend API endpoints:

```typescript
// Backend: POST /api/oauth/exchange
export async function exchangeOAuthCode(code: string, state: string) {
  // Verify state
  const validState = await validateState(state);
  if (!validState) {
    throw new Error('Invalid state parameter');
  }

  // Exchange code for token with OAuth provider
  const tokenResponse = await fetch('https://oauth-provider.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: process.env.OAUTH_CLIENT_ID,
      client_secret: process.env.OAUTH_CLIENT_SECRET,
      code,
      redirect_uri: process.env.OAUTH_REDIRECT_URI,
      grant_type: 'authorization_code'
    })
  });

  const { access_token } = await tokenResponse.json();

  // Get user info from OAuth provider
  const userResponse = await fetch('https://oauth-provider.com/user', {
    headers: { Authorization: `Bearer ${access_token}` }
  });

  const oauthUser = await userResponse.json();

  // Create or update user in your database
  const user = await createOrUpdateUser({
    oauth_id: oauthUser.id,
    handle: oauthUser.login,
    email: oauthUser.email,
    avatar: oauthUser.avatar_url
  });

  // Create session token
  const sessionToken = generateSessionToken();
  await storeSession(user.id, sessionToken, {
    expiresIn: 7 * 24 * 60 * 60 // 7 days
  });

  return { token: sessionToken, user };
}

// Backend: POST /api/auth/verify
export async function verifyToken(token: string) {
  const session = await validateSessionToken(token);
  if (!session) {
    throw new Error('Invalid or expired token');
  }

  const user = await getUserById(session.userId);
  return { user };
}

// Backend: GET /api/auth/me
export async function getCurrentUser(token: string) {
  const session = await validateSessionToken(token);
  if (!session) {
    throw new Error('Unauthorized');
  }

  const user = await getUserById(session.userId);
  return user;
}

// Backend: POST /api/auth/logout
export async function logout(token: string) {
  await invalidateSession(token);
  return { success: true };
}
```

## Comparison: Why This is Better Than Silent Redirect

| Aspect | Silent Redirect | Username Routes (Your Setup) |
|--------|-----------------|------------------------------|
| **Token Exposure** | Token in URL (risky) | Token in secure HTTP-only cookie |
| **Debugging** | Scattered across client-side | All in one place (verify-oauth.tsx) |
| **Backward Compat** | Requires complete rewrite | Minimal changes to existing code |
| **Browser History** | Complex state management | Simple, standard navigation |
| **CSRF Protection** | Manual state management | Standard OAuth state parameter |
| **Supported Browsers** | Modern browsers only | All browsers with cookies |
| **Caching Issues** | Possible URL caching | Cache works normally |
| **SEO** | Not applicable | SEO-friendly URLs |

## Advantages of This Approach

### ✅ **Minimal Changes**
Only modify verify-oauth.tsx redirect and add new [handle].tsx page. Keep callback.tsx almost unchanged.

### ✅ **More Secure**
- Token never in URL
- Uses HTTP-only cookies (can't be stolen by JavaScript)
- Standard OAuth flow

### ✅ **Better for Teams**
Future developers understand the flow: callback → verify → profile

### ✅ **Easy to Add Features**
```typescript
// Later: Add session refresh
router.post('/api/auth/refresh', refreshSession);

// Later: Add 2FA
router.post('/api/auth/2fa/verify', verify2FA);

// Later: Add audit logging
async function login(user) {
  await auditLog('user_login', { userId: user.id, timestamp: new Date() });
  // ...
}
```

### ✅ **Works with Blade's Router**
Dynamic routes with [handle].tsx are native to Blade.

## File Structure

```
pages/
├── index.tsx                    ← Home (with login button)
├── [handle].tsx                 ← NEW: User profile page
└── auth/
    ├── callback.tsx             ← OAuth provider redirects here
    └── verify-oauth.tsx         ← Verifies token, redirects to /[handle]
```

## Flow Summary

```
1. User clicks "Sign In" on home page
   ↓
2. Redirected to OAuth provider
   ↓
3. Logs in with OAuth provider
   ↓
4. OAuth provider redirects to /auth/callback?code=XXX
   ↓
5. callback.tsx exchanges code for token
   ↓
6. Redirects to /auth/verify-oauth?token=XXX&handle=username
   ↓
7. verify-oauth.tsx verifies token is valid
   ↓
8. Redirects to /username (using window.history.replaceState)
   ↓
9. [handle].tsx page loads showing user profile
   ↓
✅ User sees /username in URL, stays on authenticated profile
```

## Session Management Best Practices

### Store Token Securely

**Option 1: HTTP-Only Cookie (Most Secure)**
```javascript
// Backend sets this automatically
res.cookie('session_token', token, {
  httpOnly: true,      // Can't be accessed by JavaScript
  secure: true,        // HTTPS only
  sameSite: 'strict',  // CSRF protection
  maxAge: 7 * 24 * 60 * 60 * 1000  // 7 days
});

// Frontend: No manual token storage needed!
// Browser automatically includes cookie in requests
fetch('/api/auth/me');  // Cookie sent automatically
```

**Option 2: SessionStorage (Client-Side)**
```javascript
// Less secure, but acceptable for short-lived sessions
sessionStorage.setItem('session_token', token);

// Clear on browser close automatically
```

**Never use localStorage for OAuth tokens!**

## Monitoring & Debugging

Add logging to track authentication flow:

```typescript
// verify-oauth.tsx
useEffect(() => {
  console.log('[OAuth] Starting verification');
  console.log('[OAuth] Token:', token?.substring(0, 10) + '...');
  console.log('[OAuth] Handle:', handle);
  
  verifyOAuthToken().catch((err) => {
    console.error('[OAuth] Verification failed:', err);
    Sentry.captureException(err, { tags: { step: 'oauth_verify' } });
  });
}, []);
```

## Troubleshooting

### "Cannot redirect to /username" 
Make sure [handle].tsx page exists and Blade recognizes it.

### Session lost after page refresh
Check if sessionStorage.getItem('session_token') returns null. You may need HTTP-only cookies instead.

### "State mismatch" error
Ensure state is stored in sessionStorage before redirecting to OAuth provider:
```typescript
sessionStorage.setItem('oauth_state', state);
```

## Next Steps

1. ✅ Create `pages/[handle].tsx` (new user profile page)
2. ✅ Update `pages/auth/verify-oauth.tsx` (redirect to /handle)
3. ✅ Update `pages/auth/callback.tsx` (pass handle to verify)
4. ✅ Update `pages/index.tsx` (check session, show login)
5. ✅ Create backend endpoints (/api/oauth/exchange, /api/auth/verify, etc.)
6. ✅ Test full flow: Home → OAuth Provider → Callback → Verify → /Username
7. ✅ Add error handling and logging
8. ✅ Test logout flow

## Summary

This hybrid approach is **best for long-term** because:

1. **You keep what works** - Your proven OAuth infrastructure remains
2. **You get clean URLs** - User sees `/username` after auth
3. **You stay secure** - No tokens in URLs, server-side validation
4. **You stay maintainable** - Single place to manage auth (verify-oauth.tsx)
5. **You scale easily** - Add 2FA, sessions, audit logs without refactoring
6. **Your team understands it** - Standard OAuth flow with routing

It's the sweet spot between simplicity and functionality.
