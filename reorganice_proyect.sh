#!/bin/bash

# Crear las carpetas necesarias
mkdir -p lib/features/socket/domain/models
mkdir -p lib/features/socket/domain/repository
mkdir -p lib/features/socket/domain/services
mkdir -p lib/features/http/domain/models
mkdir -p lib/features/http/domain/repository
mkdir -p lib/features/http/domain/services
mkdir -p lib/features/setup/domain/models
mkdir -p lib/features/setup/domain/repository
mkdir -p lib/features/setup/domain/services
mkdir -p lib/features/setup/providers
mkdir -p lib/features/setup/screens
mkdir -p lib/features/setup/widgets

# Mover los archivos a sus nuevas ubicaciones
mv lib/features/socket/domain/models/socket_connection.dart lib/features/socket/domain/models/
mv lib/features/socket/domain/repository/socket_repository.dart lib/features/socket/domain/repository/
mv lib/features/socket/domain/services/socket_service.dart lib/features/socket/domain/services/
mv lib/features/socket/providers/setup_provider.dart lib/features/setup/providers/
mv lib/features/socket/screens/setup_screen.dart lib/features/setup/screens/
mv lib/features/socket/widgets/ap_selection_dialog.dart lib/features/setup/widgets/
mv lib/features/socket/widgets/show_wifi_network_dialog.dart lib/features/setup/widgets/
mv lib/features/socket/domain/models/wifi_credentials.dart lib/features/http/domain/models/
mv lib/features/socket/domain/repository/wifi_repository.dart lib/features/http/domain/repository/

# Eliminar archivos innecesarios
rm lib/features/socket/domain/models/wifi_credentials.dart
rm lib/features/socket/domain/repository/wifi_repository.dart