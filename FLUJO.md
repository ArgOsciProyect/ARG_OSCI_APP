# Flujo del Programa

## Conexión a la Red Local AP
1. `connectToLocalAP()`: Espera a que el usuario esté conectado a la red ESP32 (verificándolo con `networkInfo`).
2. Cuando el usuario está conectado, crea una instancia de `HttpService` con la IP "192.168.4.1".

## Selección del Modo de Operación
1. Hace un POST a la ESP32 con el modo seleccionado (External AP o Internal AP).
2. La ESP32 responderá:
    - **Modo External AP**: Devuelve una lista con todos los WiFis detectados por la ESP32.
    - **Modo Internal AP**: Devuelve la IP y el Puerto del socket.
        - Crea la instancia de `globalSocketService` con esta IP y este puerto.
        - La instancia de `HttpService` que estamos usando actualmente se convertirá en la instancia global.

## Modo External AP
1. El usuario selecciona el WiFi recibido y escribe su contraseña (como se ve en `show_wifi_network_dialog`).
2. Una vez tenemos el SSID y la contraseña de la red a utilizar, se la posteamos a la ESP32.
3. La ESP32 se conectará a esta red y nos responderá con una IP y un puerto.
4. Indicamos al usuario que se cambie de red WiFi a la seleccionada anteriormente y esperamos a que ocurra esto (usamos `networkInfo`).
5. Una vez cambiado de red:
    - Se setean las instancias globales de `SocketService` (usando la IP y puerto recibidos) y de `HttpService` (usando la IP recibida).

# Estructura del Código

## `SetupService`

### Métodos Públicos
- `connectToLocalAP()`: Espera a que el usuario esté conectado a la red ESP32 y crea una instancia de `HttpService`.
- `selectMode(String mode)`: Hace un POST a la ESP32 con el modo seleccionado y maneja la respuesta.
- `connectToExternalAP(String ssid, String password)`: Postea el SSID y la contraseña a la ESP32 y maneja la respuesta.
- `waitForNetworkChange(String ssid)`: Espera a que el usuario se cambie a la red WiFi seleccionada.

### Métodos Privados
- `initializeGlobalHttpService(String baseUrl)`: Inicializa la instancia global de `HttpService`.
- `initializeGlobalSocketService(String ip, int port)`: Inicializa la instancia global de `SocketService`.

## `SetupProvider`

### Métodos Públicos
- `connectToLocalAP()`: Llama al método correspondiente en `SetupService`.
- `handleModeSelection(String mode)`: Llama al método correspondiente en `SetupService` y maneja la respuesta.
- `handleExternalAPSelection()`: Llama al método correspondiente en `SetupService` y maneja la respuesta.
- `connectToExternalAP(String ssid, String password)`: Llama al método correspondiente en `SetupService`.
- `waitForNetworkChange(String ssid)`: Llama al método correspondiente en `SetupService`.

## `show_wifi_network_dialog.dart`

### Funcionalidad
- Muestra un diálogo para que el usuario seleccione un WiFi y escriba su contraseña.
- Llama a los métodos correspondientes en `SetupProvider` para manejar la selección del WiFi y la conexión a la red.