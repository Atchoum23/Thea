# TheaWeb - Thea Backend API

Swift Vapor backend for theathe.app providing:
- Sign in with Apple authentication
- Chat API for web clients
- API key management
- Rate limiting and security headers

## Quick Start

```bash
# Install dependencies
swift package resolve

# Run in development
swift run App serve

# Run tests
swift test
```

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Required environment variables:
- `APPLE_TEAM_ID` - Your Apple Developer Team ID
- `APPLE_CLIENT_ID` - Your Sign in with Apple client ID (e.g., `app.thea.ios`)

## Cloudflare Tunnel Setup

For secure external access without exposing ports:

```bash
# Install cloudflared
brew install cloudflare/cloudflare/cloudflared

# Login to Cloudflare
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create thea-api

# Route DNS
cloudflared tunnel route dns thea-api api.theathe.app

# Run tunnel
cloudflared tunnel run thea-api
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/apple` - Sign in with Apple
- `POST /api/v1/auth/refresh` - Refresh session token
- `POST /api/v1/auth/logout` - Invalidate session
- `GET /api/v1/auth/me` - Get current user
- `DELETE /api/v1/auth/account` - Delete account (GDPR)

### Chat (Protected)
- `POST /api/v1/chat/message` - Send message to Thea
- `GET /api/v1/chat/conversations` - List conversations
- `GET /api/v1/chat/conversations/:id` - Get conversation
- `DELETE /api/v1/chat/conversations/:id` - Delete conversation

### Health
- `GET /health` - Health check

## Security

Implements OWASP security recommendations:
- HTTPS only (enforced via HSTS)
- Content Security Policy
- Rate limiting (100 req/min)
- Session token hashing
- Input validation
- No sensitive data in logs
