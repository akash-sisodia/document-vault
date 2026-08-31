# Doksy

iOS on-device vault for family IDs, passports, and personal documents.

**Tagline:** Understand every document.

Scan or import papers, tag them, mark them Local or Private, and keep everything on the device. The first family profile is free; extra members require Doksy Pro.

RevenueCat entitlement: **Doksy Pro**

## Secrets (local only)

API keys are **not** stored in source. Copy the example files, then keep the real files off git:

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
cp DocumentVault/GoogleService-Info.plist.example DocumentVault/GoogleService-Info.plist
```

Fill in RevenueCat, FeedJar, and Firebase values. `Info.plist` reads `REVENUECAT_PUBLIC_API_KEY` and `FEEDJAR_API_KEY` from `Config/Secrets.xcconfig` at build time.

# document-vault
