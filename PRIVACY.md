Privacy Policy — Protopanda Controller (iOS)

Last updated: September 28, 2026

Protopanda Controller is an open-source iOS application that acts as a Bluetooth Low Energy (BLE) peripheral for Protopanda platforms.

This Privacy Policy explains what information the application accesses, how it is used, and what information is not collected.

1. Information We Collect

Protopanda Controller does not collect, store, or transmit personal information to any server.

The application does not have:

• User accounts or registration
• Login systems
• Backend servers for collecting user data
• Advertising
• User tracking
• Analytics or monitoring services
• Sale or sharing of personal information

2. Device Sensors

To provide motion controls, the application accesses the iPhone's accelerometer and gyroscope through Core Motion.

Sensor data is processed locally on the device and used only to generate movement commands sent to the connected Protopanda receiver. Sensor data is not sent to external servers or stored by the application.

3. Bluetooth

The application uses Bluetooth Low Energy (BLE), through Core Bluetooth, to act as a peripheral and communicate directly with a Protopanda receiver.

During this communication, the application transmits the information required for the controller to operate, including motion sensor data and button states. This communication occurs directly between the iPhone and the Protopanda receiver; the application does not use an intermediary server.

The app only operates while it is open and in the foreground. It does not request Bluetooth background execution and stops advertising, sensing, and notifying as soon as it leaves the foreground.

4. Permissions

The application requests Bluetooth permission (`NSBluetoothAlwaysUsageDescription`) and motion permission (`NSMotionUsageDescription`), used exclusively to provide the functionality described in this Privacy Policy.

The application does not request access to contacts, messages, photos or videos, the microphone, location, or personal files.

5. Local Storage

Configuration data required for the operation of the application (the three BLE UUIDs) is stored locally on the device using `UserDefaults`. This information remains on the device and is not transmitted to servers controlled by the developer.

6. Third-Party Services

Protopanda Controller does not use third-party services for collecting, analyzing, or tracking user data. The application may be distributed through third-party sideloading tools such as SideStore or AltStore, or through TestFlight/the App Store. Use of those platforms is subject to their respective privacy policies and terms of service.

7. Data Security

Although the application does not collect personal information on its own servers, no method of electronic communication can be considered completely secure. Users are encouraged to keep their iOS devices updated and follow the security recommendations provided by Apple.

8. Children's Privacy

The application does not knowingly collect personal information from children or users of any age. Because the application does not collect personal information, it does not create user profiles or maintain user accounts.

9. Changes to This Privacy Policy

This Privacy Policy may be updated if the application's functionality changes or new features are introduced. When significant changes are made, the updated version will be made available alongside the project. The date at the beginning of this Privacy Policy indicates when it was last updated.

10. Open-Source Project

Protopanda Controller (iOS) is an open-source project. Its source code is publicly available on GitHub:

https://github.com/junglivre/ProtopandaController-iOS

The Android version lives at:

https://github.com/junglivre/ProtopandaController

11. Contact

If you have any questions about this Privacy Policy or the application's handling of information, you can contact the developer through the project's GitHub repository.

Protopanda Controller
Open-source project by Jung / junglivre, and contributors.
