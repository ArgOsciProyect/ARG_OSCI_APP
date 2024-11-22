#!/bin/bash

# Crear las carpetas necesarias
mkdir -p lib/features/socket/domain/models
mkdir -p lib/features/socket/domain/repository
mkdir -p lib/features/socket/domain/services
mkdir -p lib/features/socket/providers
mkdir -p lib/features/socket/screens
mkdir -p lib/features/socket/widgets

# Mover los archivos a sus nuevas ubicaciones
mv lib/domain/models/socket_connection.dart lib/features/socket/domain/models/
mv lib/domain/repository/socket_repository.dart lib/features/socket/domain/repository/
mv lib/domain/services/socket_service.dart lib/features/socket/domain/services/
mv lib/providers/setup_provider.dart lib/features/socket/providers/
mv lib/screens/setup_screen.dart lib/features/socket/screens/
mv lib/widgets/ap_selection_dialog.dart lib/features/socket/widgets/
mv lib/widgets/show_wifi_network_dialog.dart lib/features/socket/widgets/