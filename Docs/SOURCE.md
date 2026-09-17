# Provenance and deployment references

Source: latest successfully deployed RiseBake app `risebake-s4otbp`, version `1789473015082`, retrieved 15 September 2026. Ported `src/core.js` behaviors and `src/app.js` screens, following the latest `src/ios.css` and `src/ios-chrome.js` visual revision. Product images were extracted from the same `src/assets/bakes.webp` sprite. No page screenshots are shipped as UI.

The two bundled `seed.json` files are identical fictional demo fixtures generated from the source app's `seed()` function, not exported customer records or browser storage. All eight contact addresses use `example.test`; phone numbers and message histories are empty. The 35 orders and four recurring plans are demonstration scenarios with simulated payments. Local compiler and test logs are excluded from the public repository.

Official references consulted 15 September 2026:

- https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/
- https://docs.codemagic.io/yaml-code-signing/ios-simulator-builds/
- https://docs.codemagic.io/integrations/appetize-integration/
- https://docs.appetize.io/platform/app-management/uploading-apps/ios
- https://docs.appetize.io/rest-api/v1/direct-file-uploads
- https://docs.appetize.io/rest-api/v1/create-new-app
- https://docs.appetize.io/rest-api/v1/update-existing-app

Appetize's current upload API uses `X-API-KEY`, supports direct multipart uploads and accepts simulator `.app` ZIPs. The workflow uses an ARM simulator build as recommended in Appetize's iOS upload documentation. Credentials are supplied at runtime from Codemagic secrets.
