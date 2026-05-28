@echo off
echo ========================================
echo Запуск через ADB reverse (рекомендуется для USB)
echo ========================================
echo.

REM Проверяем, запущен ли сервер
echo Проверка сервера...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:8001/health' -UseBasicParsing -TimeoutSec 2; echo OK } catch { echo FAIL }" | findstr /C:"OK" >nul
if errorlevel 1 (
    echo ОШИБКА: Сервер не запущен на localhost:8001
    echo Запустите сначала: run_server.bat
    pause
    exit /b 1
)

echo Сервер работает.
echo.

REM Проверяем ADB устройство
echo Проверка подключенного Android устройства...
adb devices | findstr /C:"device" >nul
if errorlevel 1 (
    echo ОШИБКА: Устройство не найдено или отладка не включена
    echo Убедитесь, что:
    echo 1. На телефоне включена отладка по USB (Настройки -> Для разработчиков)
    echo 2. Телефон подключен по USB кабелю
    echo 3. Установлены ADB драйверы
    pause
    exit /b 1
)

echo Устройство найдено.
echo.

REM Делаем проброс портов
echo Проброс порта 8001 на устройство...
adb reverse tcp:8001 tcp:8001
if errorlevel 1 (
    echo ОШИБКА: Не удалось выполнить adb reverse
    echo Попробуйте вручную: adb reverse tcp:8001 tcp:8001
    pause
    exit /b 1
)

echo Порт проброшен успешно!
echo Теперь на телефоне http://localhost:8001 будет указывать на компьютер
echo.

REM Устанавливаем зависимости
echo Установка Flutter зависимостей...
flutter pub get
if errorlevel 1 (
    echo ОШИБКА: Не удалось установить зависимости
    pause
    exit /b 1
)

REM Запускаем приложение с localhost
echo.
echo ========================================
echo Запуск приложения...
echo Сервер: http://localhost:8001 (через ADB reverse)
echo ========================================
echo.

flutter run --dart-define=SERVER_URL=http://localhost:8001

if errorlevel 1 (
    echo.
    echo ОШИБКА: Не удалось запустить приложение
    pause
    exit /b 1
)
