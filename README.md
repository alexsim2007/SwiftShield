# SwiftShield VPN

Нативный iOS-клиент на SwiftUI с Packet Tunnel Provider. Проект уже умеет импортировать и хранить профили, создавать системную VPN-конфигурацию и запускать Network Extension. Передача трафика намеренно отключена до подключения настоящего сетевого ядра.

## Что уже есть

- SwiftUI-интерфейс: подключение, профили и настройки.
- Импорт `vless://`, `trojan://`, `ss://`, Base64-подписок и базового sing-box JSON.
- Хранилище в App Group с iOS Data Protection.
- `NETunnelProviderManager` и `NEPacketTunnelProvider`.
- Unit-тесты парсера.

## Первый запуск

1. Принять лицензию установленного Xcode: `sudo xcodebuild -license`.
2. Создать проект: `xcodegen generate`.
3. Открыть `SwiftShield.xcodeproj` в Xcode.
4. Выбрать свою Team для targets `SwiftShield` и `TunnelExtension`.
5. Заменить `com.swiftshield.app` и `group.com.swiftshield.app`, если эти идентификаторы заняты в Apple Developer.
6. Включить Network Extensions и App Groups для обоих App ID.

Системный Packet Tunnel нужно проверять на физическом iPhone. Симулятор подходит для UI и импорта, но не для полноценной проверки VPN.

## Следующий сетевой этап

Нужно собрать `Libbox.xcframework` из sing-box, добавить его в `TunnelExtension` и реализовать адаптер вместо `UnavailableTunnelEngine`. sing-box распространяется по GPL-3.0; до публикации приложения необходимо согласовать модель распространения исходного кода и выполнение лицензии.

