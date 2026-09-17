# Test RiseBake on an iPhone using Windows

RiseBake requires iOS 17 or later. Windows handles installation; the app runs on your iPhone. A free Apple Account works. No Mac, jailbreak, or paid Apple Developer membership is needed for this route.

1. In GitHub, open **Actions > Build RiseBake iPhone IPA > Run workflow**, or use the latest successful run. Download its **RiseBake-iPhone** artifact and extract **RiseBake-unsigned.ipa**. Alternatively, run **ios-sideload** in Codemagic and download the IPA from that build. Both workflows build a Release app for a physical iPhone and check its architecture, platform, and IPA layout. The simulator ZIP cannot install on your phone. Apple signing credentials are not needed in either build service: Sideloadly signs the IPA later.
2. Install [Sideloadly](https://sideloadly.io/) on Windows, along with the **web versions of iTunes and iCloud linked on that site**. Sideloadly instructs users with Microsoft Store versions to uninstall those first.
3. Connect your unlocked iPhone by USB and tap **Trust This Computer** if asked. Open Sideloadly, select the phone, and load `RiseBake-unsigned.ipa`. Enter your Apple Account directly in Sideloadly, enable automatic refreshing, and click **Start**. Complete its password and two-factor prompts yourself; do not paste credentials into chat.
4. On the iPhone, follow any **Untrusted Developer** prompt under **Settings > General > VPN & Device Management**, then trust the account used to install. Enable **Settings > Privacy & Security > Developer Mode** if requested, restart, and confirm after restarting. The Developer Mode setting may appear only after pairing or the installation attempt. Open **RiseBake** from the Home Screen.

Free signing lasts **7 days** and allows up to **3 sideloaded apps per device**. Keep Sideloadly's daemon running on Windows and the phone reachable by USB or configured Wi-Fi so it can refresh the app. For Wi-Fi, use iTunes > your device > Summary > Options > **Sync with this iPhone over Wi-Fi**, then Sync. Both devices need the same network.

For later builds, install over the existing app using the same Apple Account and bundle ID. Avoid deleting the app if you want to retain its local data; use RiseBake's JSON backup to keep a separate copy. This workflow checks the package but cannot verify a launch on your physical phone; open and test it after installation.

References: [Sideloadly setup and FAQ](https://sideloadly.io/faq), [Apple free-account limits](https://developer.apple.com/help/account/basics/about-your-developer-account), [Apple Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), [Codemagic unsigned builds](https://docs.codemagic.io/yaml-quick-start/first-signed-build/).
