# Публикация SwiftShield в TestFlight

## 1. Что понадобится

- Платная подписка Apple Developer Program.
- Apple Account, добавленный в Xcode.
- Доступ к App Store Connect с ролью Account Holder, Admin, App Manager или Developer.
- Физический iPhone для проверки настоящего Packet Tunnel.

Симулятор подходит для интерфейса, но не способен запустить системный VPN. Ошибка `IPC failed` в Simulator не означает, что Packet Tunnel сломан.

## 2. Добавить Apple Account в Xcode

1. Откройте Xcode.
2. В верхнем меню нажмите `Xcode > Settings`.
3. Откройте вкладку `Accounts`.
4. Нажмите `+` в левом нижнем углу.
5. Выберите `Apple Account` и войдите в аккаунт разработчика.
6. Убедитесь, что рядом с аккаунтом отображается нужная Team.

## 3. Проверить идентификаторы Apple Developer

Откройте [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).

### App Group

1. Откройте `Identifiers`.
2. Нажмите `+`.
3. Выберите `App Groups`, затем `Continue`.
4. Description: `SwiftShield`.
5. Identifier: `group.com.swiftshield.app`.
6. Нажмите `Continue`, затем `Register`.

Если такой идентификатор уже занят другой Team, придумайте уникальный, например `group.dev.вашеимя.swiftshield`, и замените его во всём проекте.

### Основное приложение

1. В `Identifiers` нажмите `+`.
2. Выберите `App IDs`, затем `Continue`.
3. Выберите тип `App`, затем `Continue`.
4. Description: `SwiftShield`.
5. Выберите `Explicit Bundle ID`.
6. Bundle ID: `com.swiftshield.app`.
7. В Capabilities включите `App Groups` и `Network Extensions`.
8. Для Network Extensions отметьте Packet Tunnel, если портал показывает список типов.
9. Нажмите `Continue`, затем `Register`.
10. Откройте созданный Identifier, нажмите `Configure` рядом с App Groups и выберите `group.com.swiftshield.app`.

### Tunnel Extension

Повторите создание App ID со значениями:

- Description: `SwiftShield Tunnel`.
- Bundle ID: `com.swiftshield.app.TunnelExtension`.
- Capabilities: `App Groups` и `Network Extensions`.
- App Group: `group.com.swiftshield.app`.

### Widget Extension

Повторите создание App ID со значениями:

- Description: `SwiftShield Widgets`.
- Bundle ID: `com.swiftshield.app.Widgets`.
- Capability: `App Groups`.
- App Group: `group.com.swiftshield.app`.

При включённом Automatic Signing Xcode часто создаёт эти идентификаторы сам. Ручная проверка выше помогает избежать ошибок entitlement при архивировании.

## 4. Настроить Signing в Xcode

1. Откройте `SwiftShield.xcodeproj`.
2. В левой панели Project Navigator нажмите самый верхний синий файл `SwiftShield`.
3. В центральной панели в разделе `TARGETS` выберите `SwiftShield`.
4. Откройте вкладку `Signing & Capabilities`.
5. Включите `Automatically manage signing`.
6. В поле `Team` выберите свою Team.
7. Убедитесь, что Bundle Identifier равен `com.swiftshield.app`.
8. Повторите шаги для target `TunnelExtension`; Bundle ID должен быть `com.swiftshield.app.TunnelExtension`.
9. Повторите шаги для target `SwiftShieldWidgets`; Bundle ID должен быть `com.swiftshield.app.Widgets`.
10. Красных ошибок в `Signing & Capabilities` быть не должно.

Если Bundle ID занят, сначала измените идентификаторы в `project.yml`, `AppConstants.swift` и entitlements, затем в Terminal из папки проекта выполните `xcodegen generate`.

## 5. Проверить на физическом iPhone

1. Подключите iPhone к Mac кабелем или включите беспроводное подключение в Xcode.
2. Разблокируйте iPhone и подтвердите доверие компьютеру.
3. Если iPhone попросит включить Developer Mode, откройте `Настройки > Конфиденциальность и безопасность > Режим разработчика`, включите его и перезагрузите устройство.
4. В верхней панели Xcode нажмите на выбор устройства рядом со схемой `SwiftShield`.
5. Выберите подключённый iPhone.
6. Нажмите кнопку Run с треугольником или `Product > Run`.
7. На iPhone импортируйте настоящий профиль и нажмите кнопку подключения.
8. Подтвердите системный запрос `SwiftShield хочет добавить конфигурации VPN`.
9. Проверьте открытие сайтов, отключение VPN, экран блокировки и Dynamic Island.

## 6. Создать приложение в App Store Connect

1. Откройте [App Store Connect](https://appstoreconnect.apple.com/).
2. Нажмите `My Apps`.
3. Нажмите `+` в левом верхнем углу.
4. Выберите `New App`.
5. Platforms: `iOS`.
6. Name: `SwiftShield` или другое свободное публичное имя.
7. Primary Language: `Russian` или нужный основной язык.
8. Bundle ID: выберите `com.swiftshield.app`.
9. SKU: например `swiftshield-ios-001`. Пользователи его не увидят.
10. User Access: `Full Access`.
11. Нажмите `Create`.

## 7. Подготовить Archive

1. Вернитесь в Xcode.
2. В верхней панели выберите схему `SwiftShield`.
3. В списке устройств выберите `Any iOS Device (arm64)` или `Generic iOS Device`.
4. Откройте `Product > Clean Build Folder`, удерживая Option, если Xcode показывает старые ошибки.
5. Нажмите `Product > Archive`.
6. Дождитесь открытия окна Organizer.

Если пункт Archive неактивен, выбран Simulator. Переключитесь на `Any iOS Device (arm64)`.

## 8. Проверить и загрузить архив

1. В Organizer слева выберите свежий архив `SwiftShield`.
2. Нажмите `Validate App`.
3. Выберите `App Store Connect` и автоматическое управление подписью.
4. Исправьте ошибки Validation, если они появились.
5. После успешной проверки нажмите `Distribute App`.
6. Выберите `App Store Connect`.
7. Выберите `Upload`.
8. Оставьте включёнными загрузку символов и автоматическое управление подписью.
9. Нажимайте `Next`, затем `Upload`.
10. Дождитесь сообщения `Upload Successful`.

## 9. Дождаться обработки в App Store Connect

1. Откройте App Store Connect и выберите SwiftShield.
2. Откройте вкладку `TestFlight`.
3. Сборка `0.2.0 (2)` сначала будет иметь статус Processing.
4. Обработка обычно занимает несколько минут, но иногда дольше.
5. Apple пришлёт письмо, когда обработка закончится или найдётся ошибка.

Каждая следующая загрузка должна иметь новый Build Number. Для следующей сборки измените `CURRENT_PROJECT_VERSION: 2` на `3` в `project.yml` и выполните `xcodegen generate`.

## 10. Заполнить Export Compliance

SwiftShield включает sing-box и использует шифрование. Не указывайте, что приложение не использует шифрование, только ради пропуска формы.

1. Если рядом со сборкой написано `Missing Compliance`, нажмите `Manage`.
2. Нажмите `Provide Export Compliance Information`.
3. Ответьте на вопросы в соответствии с реально используемыми протоколами и регионами распространения.
4. Если App Store Connect запросит документы, откройте `Services > Encryption` и загрузите их.
5. После одобрения Apple может выдать compliance code для Info.plist.

## 11. Добавить внутренних тестировщиков

1. В App Store Connect откройте `Users and Access`.
2. Нажмите `+` и добавьте Apple Account тестировщика, если его ещё нет в команде.
3. Вернитесь в `My Apps > SwiftShield > TestFlight`.
4. В секции `Internal Testing` нажмите `+` рядом с группами.
5. Создайте группу, например `SwiftShield Internal`.
6. Откройте группу и нажмите `Add Testers`.
7. Выберите пользователей команды.
8. Нажмите `Add Builds` и выберите `0.2.0 (2)`.
9. Тестировщику придёт приглашение. Он устанавливает приложение TestFlight из App Store и принимает приглашение.

## 12. Добавить внешних тестировщиков

1. Во вкладке `TestFlight` нажмите `+` рядом с `External Testing`.
2. Создайте группу, например `SwiftShield Beta`.
3. Нажмите `Add Builds` и выберите нужную сборку.
4. Заполните `What to Test`, например: `Проверьте импорт профиля, подключение, отключение, DNS, экран блокировки и Dynamic Island`.
5. Заполните Beta App Review Information: контакт, телефон, email и пояснение, откуда тестировщик берёт VPN-профиль.
6. Нажмите `Submit for Review`.
7. После Beta App Review добавьте email тестировщиков или включите Public Link.

## Частые ошибки

### Bundle Identifier is not available

Идентификатор занят. Используйте уникальные Bundle ID и App Group, затем перегенерируйте проект.

### Provisioning profile does not include the Network Extensions entitlement

Проверьте Network Extensions у основного App ID и Tunnel Extension, затем выключите и снова включите Automatic Signing.

### App Group entitlement mismatch

У `SwiftShield`, `TunnelExtension` и `SwiftShieldWidgets` должна быть одна App Group с абсолютно одинаковой строкой.

### IPC failed в Simulator

Packet Tunnel нельзя проверять в Simulator. Запустите приложение на физическом iPhone.

### Build number has already been used

Увеличьте `CURRENT_PROJECT_VERSION`, выполните `xcodegen generate` и создайте новый Archive.

### Missing Compliance

Откройте `Manage` рядом со сборкой и заполните Export Compliance. Не добавляйте `ITSAppUsesNonExemptEncryption = NO` без уверенности, что это юридически корректно.
