# SwiftShield VPN

Нативный iOS-клиент на SwiftUI с Packet Tunnel Provider и сетевым ядром sing-box. Проект импортирует профили, создаёт системную VPN-конфигурацию и передаёт трафик через нативный `Libbox.xcframework`.

## Что уже есть

- SwiftUI-интерфейс: подключение, профили и настройки.
- Импорт `vless://`, `trojan://`, `ss://`, Base64-подписок и базового sing-box JSON.
- Хранилище в App Group с iOS Data Protection.
- `NETunnelProviderManager` и `NEPacketTunnelProvider`.
- Воспроизводимая сборка `libbox` для iPhone и iOS Simulator.
- TUN bridge, системные маршруты и защищённый DNS через выбранный прокси.
- MUX, фрагментация TLS/UDP, TCP Fast Open, XUDP, DNS/IP-стратегии и настройка MTU.
- Live Activity для экрана блокировки и Dynamic Island с быстрым отключением.
- Чёрно-белый интерфейс без цветных акцентов.
- Монохромная App Store icon и privacy manifest.
- Unit-тесты парсера и генератора конфигурации.

## Первый запуск

1. Принять лицензию установленного Xcode: `sudo xcodebuild -license`.
2. При отсутствии `Vendor/Libbox.xcframework` выполнить `Scripts/build-libbox.sh`.
3. Создать проект: `xcodegen generate`.
4. Открыть `SwiftShield.xcodeproj` в Xcode.
5. Выбрать свою Team для targets `SwiftShield`, `TunnelExtension` и `SwiftShieldWidgets`.
6. Заменить `com.swiftshield.app` и `group.com.swiftshield.app`, если эти идентификаторы заняты в Apple Developer.
7. Включить Network Extensions и App Groups для обоих App ID.

Системный Packet Tunnel нужно проверять на физическом iPhone. Симулятор подходит для UI и импорта, но не для полноценной проверки VPN.

Инструкция по первой бета-сборке: [TESTFLIGHT.md](TESTFLIGHT.md).

## Лицензия ядра

sing-box распространяется по GPL-3.0. До публикации приложения необходимо выполнить требования этой лицензии к распространению исходного кода.
