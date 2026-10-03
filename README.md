# SwiftShield VPN

Нативный iOS-клиент на SwiftUI с Packet Tunnel Provider. Проект умеет импортировать и хранить профили, создавать системную VPN-конфигурацию и запускать Network Extension. Нативный `Libbox.xcframework` уже собирается и подключён к target расширения; запуск трафика через его platform bridge будет следующим этапом.

## Что уже есть

- SwiftUI-интерфейс: подключение, профили и настройки.
- Импорт `vless://`, `trojan://`, `ss://`, Base64-подписок и базового sing-box JSON.
- Хранилище в App Group с iOS Data Protection.
- `NETunnelProviderManager` и `NEPacketTunnelProvider`.
- Воспроизводимая сборка `libbox` для iPhone и iOS Simulator.
- Чёрно-белый интерфейс без цветных акцентов.
- Unit-тесты парсера.

## Первый запуск

1. Принять лицензию установленного Xcode: `sudo xcodebuild -license`.
2. При отсутствии `Vendor/Libbox.xcframework` выполнить `Scripts/build-libbox.sh`.
3. Создать проект: `xcodegen generate`.
4. Открыть `SwiftShield.xcodeproj` в Xcode.
5. Выбрать свою Team для targets `SwiftShield` и `TunnelExtension`.
6. Заменить `com.swiftshield.app` и `group.com.swiftshield.app`, если эти идентификаторы заняты в Apple Developer.
7. Включить Network Extensions и App Groups для обоих App ID.

Системный Packet Tunnel нужно проверять на физическом iPhone. Симулятор подходит для UI и импорта, но не для полноценной проверки VPN.

## Следующий сетевой этап

Нужно реализовать platform bridge вместо `UnavailableTunnelEngine`: передать sing-box файловый дескриптор TUN, применить маршруты и DNS, затем запускать конфигурацию выбранного профиля. sing-box распространяется по GPL-3.0; до публикации приложения необходимо выполнить требования этой лицензии к распространению исходного кода.
