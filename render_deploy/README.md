# AIRA SMTP Bridge — Cloud Email Relay

A lightweight Python server that delivers emails for the AIRA/AIRAMP
Firebase-hosted web application.

## What it does

1. **Polls Cloud Firestore** every 5 seconds for emails with `status: "pending"`
2. **Sends them via Gmail SMTP** using your App Password
3. **Updates Firestore** document status to `"sent_via_smtp"` or `"failed"`
4. Also accepts direct HTTP POST requests at `/send-email`

## Deploy to Render.com

1. Push this folder to a GitHub repository
2. Create a **Web Service** on [render.com](https://render.com)
3. Connect your GitHub repo
4. Set these **Environment Variables** in the Render dashboard:

| Variable | Value |
|----------|-------|
| `SMTP_SENDER_EMAIL` | Your Gmail address |
| `SMTP_APP_PASSWORD` | Your Gmail App Password |
| `FIREBASE_PROJECT_ID` | `aira-app-database` |

5. Deploy — done!

## Health Check

Visit `https://your-service.onrender.com/` to verify the service is online.

