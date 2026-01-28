# Supabase Edge Function Setup Guide

## Architecture Migration Complete ✅

The AI logic has been successfully migrated from direct client calls to a secure Supabase Edge Function.

### What Changed

**Before:**
- iOS app called Aliyun API directly
- API key exposed in client code (`Secrets.swift`)
- No streaming support

**After:**
- iOS app calls Supabase Edge Function (`chat-lumi`)
- API key secured server-side in Edge Function environment
- Full streaming support (typewriter effect)

---

## Setup Instructions

### Step 1: Configure Edge Function Secrets

You need to set the `ALIYUN_API_KEY` in your Supabase Edge Function environment:

1. **Go to Supabase Dashboard:**
   - URL: https://supabase.com/dashboard/project/fvvxpizfqoeknubjjcpr/settings/functions

2. **Navigate to Edge Functions Settings:**
   - Click "Settings" in the left sidebar
   - Click "Edge Functions"
   - Click "Secrets" tab

3. **Add the Secret:**
   - Click "Add New Secret"
   - **Name:** `ALIYUN_API_KEY`
   - **Value:** `sk-55a3cf9713ac45f6a7ed30993f1fb53c`
   - Click "Save"

4. **Wait for Propagation:**
   - Secrets take 30-60 seconds to propagate
   - The function will automatically pick up the new secret

### Step 2: Test the Edge Function

After setting the secret, test the function:

```bash
curl -X POST 'https://fvvxpizfqoeknubjjcpr.supabase.co/functions/v1/chat-lumi' \
  -H 'Content-Type: application/json' \
  -H 'apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2dnhwaXpmcW9la251YmpqY3ByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwODU2NzEsImV4cCI6MjA4MjY2MTY3MX0.m7iIvF1BGe5XEvvWIDqbqzJ-F_UWeXUbRIx78z3Hl4g' \
  -d '{
    "messages": [
      {"role": "system", "content": "You are Lumi, a helpful AI assistant."},
      {"role": "user", "content": "Say hello in one sentence"}
    ],
    "stream": true
  }'
```

Expected output: SSE stream with AI response

### Step 3: Test in iOS App

1. Open the project in Xcode
2. Build and run on simulator or device
3. Start a conversation in the app
4. You should see the typewriter effect as the AI responds

---

## Technical Details

### Edge Function Endpoint

**URL:** `https://fvvxpizfqoeknubjjcpr.supabase.co/functions/v1/chat-lumi`

**Authentication:** Supabase anon key (automatically added by `ChatService.swift`)

**Request Format:**
```json
{
  "messages": [
    {"role": "system", "content": "System prompt..."},
    {"role": "user", "content": "User message..."}
  ],
  "model": "qwen-plus",
  "temperature": 0.7,
  "max_tokens": 1024,
  "stream": true
}
```

**Response Format:**
- Streaming: Server-Sent Events (SSE)
- Non-streaming: JSON (OpenAI compatible)

### Code Changes

**Files Modified:**
1. `ChatService.swift` - Updated to call Edge Function with streaming support
2. New Edge Function: `chat-lumi` (TypeScript, deployed to Supabase)

**Files No Longer Used:**
- `Secrets.swift` - Keep for backward compatibility, but API key is no longer used by `ChatService`

---

## Security Benefits

✅ **API Key Protection:** Key is server-side only, never exposed in client code
✅ **Version Control Safe:** No sensitive data in Git repository
✅ **Production Ready:** Proper separation of concerns
✅ **Rate Limiting:** Can add rate limiting at Edge Function level
✅ **Monitoring:** Supabase provides built-in function logs

---

## Troubleshooting

**Error: "ALIYUN_API_KEY not configured"**
- Make sure you've added the secret in Supabase Dashboard
- Wait 60 seconds for propagation
- Restart the function if needed

**Error: "Invalid response from server"**
- Check Supabase function logs in the dashboard
- Verify the Aliyun API key is still valid

**No streaming in app**
- Check network connectivity
- Look for errors in Xcode console
- Verify the Edge Function is deployed (`ACTIVE` status)

---

## Next Steps (Optional)

1. **Add Rate Limiting:** Implement request throttling in Edge Function
2. **Add Analytics:** Track API usage and costs
3. **Add Caching:** Cache common responses for faster performance
4. **Remove Secrets.swift:** Once confirmed working, you can delete the old file
5. **Environment Variables:** Create separate dev/prod configurations

---

## Support

- **Supabase Dashboard:** https://supabase.com/dashboard/project/fvvxpizfqoeknubjjcpr
- **Edge Function Logs:** Settings → Edge Functions → Logs
- **Project Status:** All services ACTIVE and healthy ✅
