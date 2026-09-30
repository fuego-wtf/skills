# OpenDisplay quick-start checklist

Use the Mac sender and the universal iPad/iPhone receiver. The receiver is available from the App Store or the public TestFlight invitation:

- App Store: https://apps.apple.com/app/id6754265378
- TestFlight: https://testflight.apple.com/join/3NYaY11c

The first connection must be made with a physical monitor still attached. Connect a direct, data-capable USB-C cable, unlock the iPad or iPhone, accept the trust prompt, and keep the receiver open. On macOS, grant Screen Recording and Accessibility to OpenDisplay.

Select **Extend** in OpenDisplay and wait for `Extending to iPad`. Do not select Mirror: Mirror captures the physical monitor and freezes when it is unplugged. After Extend is verified, unplug only the physical monitor; keep the iPad or iPhone USB cable connected.

For a frozen screen, reconnect the physical monitor, reconnect the iPad or iPhone, reopen both apps, select Extend again, and verify the log. Café Wi-Fi is not a dependable fallback because client isolation can block Bonjour; use USB or a private hotspot/router.
