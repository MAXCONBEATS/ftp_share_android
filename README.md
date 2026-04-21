# FTP Share 📁➡️💻

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)](https://github.com/yourname/ftp_share_android)

Простое и удобное приложение для передачи файлов с телефона на компьютер (и обратно) по Wi-Fi с использованием протокола FTP. Написано на **Flutter**, работает на **Android** и **iOS**.

## 🚀 Как это работает

1. Нажмите кнопку **«Пуск»** — приложение запустит встроенный FTP-сервер.
2. На экране появится адрес вида `ftp://192.168.1.5:1111`.
3. Откройте этот адрес в проводнике Windows, Finder на Mac или любом FTP-клиенте (FileZilla).
4. Готово! Вы видите папку `FTPShare` на телефоне и можете свободно копировать/удалять файлы.

## ✨ Основные функции

- **Запуск FTP-сервера в один клик** на выбранном порту (по умолчанию `1111`).
- **Опциональная защита паролем** (анонимный вход по умолчанию).
- **Автоматическое создание общей папки** `FTPShare` в публичной директории `Downloads` (Android) или `Documents` (iOS).
- **Встроенный выбор файлов**: можно добавить фото, видео или любые другие файлы из галереи/файловой системы прямо в папку FTP перед отправкой.
- **Открытие папки FTP** в системном файловом менеджере для быстрого доступа.
- **Отображение IP-адреса и пути** — всё готово для подключения с ПК.

## 📸 Скриншоты

*(Рекомендуется добавить реальные скриншоты главного экрана и страницы выбора файлов)*

| Главный экран | Выбор файлов |
|---------------|--------------|
| ![Главный экран](screenshots/main.png) | ![Выбор файлов](screenshots/select.png) |

## 📦 Используемые пакеты

- [ftp_server](https://pub.dev/packages/ftp_server) – ядро FTP-сервера.
- [network_info_plus](https://pub.dev/packages/network_info_plus) – получение IP-адреса в Wi-Fi сети.
- [permission_handler](https://pub.dev/packages/permission_handler) – запрос разрешений на доступ к файлам.
- [image_picker](https://pub.dev/packages/image_picker) / [file_picker](https://pub.dev/packages/file_picker) – выбор медиа и файлов.
- [external_path](https://pub.dev/packages/external_path) – получение пути к общей папке Downloads на Android.
- [path_provider](https://pub.dev/packages/path_provider) / [open_file](https://pub.dev/packages/open_file) – работа с директориями и открытие папок.

## 🔧 Сборка и установка

1. Убедитесь, что у вас установлен Flutter SDK.
2. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/yourusername/ftp_share_android.git
   cd ftp_share_android
3. Получите зависимости:
   ```bash
   flutter pub get
4. Запустите на устройстве:
   ```bash
   flutter run
## ⚠️ Важно
FTP-сервер работает только в локальной Wi-Fi сети. Для доступа из интернета требуется проброс портов (не рекомендуется).

Для максимальной совместимости на Android приложение создаёт папку FTPShare внутри публичной директории Download. Если доступ к ней запрещён системой, будет использована внутренняя папка приложения.

##📄 Лицензия
Осутствует.