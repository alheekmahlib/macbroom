# MacBroom Setup Guide — Final Steps

## ✅ Done (Automated)
- [x] Sparkle added to Package.swift
- [x] UpdateManager.swift created
- [x] Info.plist updated with SUFeedURL
- [x] "Check for Updates" button in Settings
- [x] GitHub Actions workflow for releases (.github/workflows/release.yml)
- [x] GitHub Actions workflow for website deployment
- [x] appcast.xml created in website/public/
- [x] .gitignore created
- [x] Initial commit done

## 🔧 Required: Manual Steps

### Step 1: Login to GitHub CLI
```bash
gh auth login
# Choose: GitHub.com → HTTPS → Login with web browser
```

### Step 2: Create GitHub Repos
```bash
# MacBroom app
cd /Users/hawazenmahmood/Documents/GitHub/MacBroom
gh repo create alheekmahlib/macbroom --private --source=. --push

# Website
cd /Users/hawazenmahmood/Documents/GitHub/macbroom-website
gh repo create alheekmahlib/macbroom-website --public --source=. --push
```

### Step 3: Enable GitHub Pages (for website)
1. Go to: https://github.com/alheekmahlib/macbroom-website/settings/pages
2. Source: "GitHub Actions"
3. Push to main branch → auto-deploys

### Step 4: Generate Sparkle EdDSA Keys
```bash
# Install Sparkle tools
brew install sparkle

# Generate keys (SAVE THESE SECURELY!)
generate_keys
# Copy the PUBLIC key → paste in Info.plist (SUPublicEDKey)
# Add PRIVATE key to GitHub Secrets (SPARKLE_PRIVATE_KEY)
```

### Step 5: Add GitHub Secrets
Go to: https://github.com/alheekmahlib/macbroom/settings/secrets/actions

Add these secrets:
- `DEVELOPER_ID_CERT` — Base64 of your Developer ID certificate (.p12)
- `DEVELOPER_ID_PASSWORD` — Certificate password
- `KEYCHAIN_PASSWORD` — Temporary keychain password
- `APPLE_ID` — Your Apple ID email
- `APPLE_APP_PASSWORD` — App-specific password from appleid.apple.com
- `TEAM_ID` — QMY79485Y6
- `SPARKLE_PRIVATE_KEY` — From generate_keys

### Step 6: Export Certificate
```bash
# Export your Developer ID cert as .p12
# Open Keychain Access → My Certificates → "Developer ID Application: ..."
# Right-click → Export → Save as .p12 → Set password

# Base64 encode it
base64 -i certificate.p12 | pbcopy
# Paste as DEVELOPER_ID_CERT secret
```

### Step 7: First Release!
```bash
cd /Users/hawazenmahmood/Documents/GitHub/MacBroom
git tag v1.0.0
git push origin v1.0.0
# GitHub Actions will build, sign, notarize, and create the release!
```

### Step 8: Update appcast.xml
After the release is created, update public/appcast.xml with:
- The correct download URL from GitHub Release
- The EdDSA signature from sign_update
- The file size
Then push to website repo.

## 📁 URLs
- Website: https://alheekmahlib.github.io/macbroom-website
- Appcast: https://alheekmahlib.github.io/macbroom-website/appcast.xml
- Releases: https://github.com/alheekmahlib/macbroom/releases
