# Documentación Técnica - Osciloscopio AR

## Índice
1.  Marco Teórico y Conceptos Fundamentales
2.  Sistema de Inicialización y Configuración
    *   2.1 Proceso de Inicialización
        *   2.1.1 Configuración Base del Sistema
        *   2.1.2 Estructura de Navegación
    *   2.2 Sistema de Inicialización Jerárquica
        *   2.2.1 Gestión de Dependencias
3.  Sistema de Configuración y Conexión
    *   3.1 Establecimiento de Conexión
        *   3.1.1 Modos de Conexión
        *   3.1.2 Proceso de Conexión al AP Local
    *   3.2 Servicios de Red
        *   3.2.1 NetworkInfoService
        *   3.2.2 Dependencias
    *   3.3 Interfaz de Usuario
        *   3.3.1 Pantalla de Configuración (SetupScreen)
        *   3.3.2 Diálogos del Sistema
    *   3.4 Flujo de Configuración
        *   3.4.1 Proceso de Inicialización
        *   3.4.2 Flujos de Operación
4.  Servicios de Comunicación
    *   4.1 Sistema de Comunicación HTTP
        *   4.1.1 Arquitectura y Componentes
        *   4.1.2 Operaciones del Sistema
    *   4.2 Sistema de Comunicación Socket
        *   4.2.1 Estructura Principal
        *   4.2.2 Sistema de Transmisión de Datos
        *   4.2.3 Gestión de Eventos y Recursos
5.  Sistema de Visualización y Procesamiento
    *   5.1 Configuración y Adquisición de Datos
        *   5.1.1 Configuración del Hardware
        *   5.1.2 Sistema de Escalado
    *   5.2 Preprocesamiento y Gestión de Datos
        *   5.2.1 Arquitectura de Procesamiento
        *   5.2.2 Sistema de Trigger
        *   5.2.3 Sistema de Filtrado
        *   5.2.4 Sistema de Escalado
        *   5.2.5 Métricas y Autoajuste
        *   5.2.6 Sistema de Estado
    *   5.3 Visualización Temporal
        *   5.3.1 Arquitectura de Visualización
        *   5.3.2 Gestión de Estado (LineChartProvider)
        *   5.3.3 Procesamiento de Datos
        *   5.3.4 Optimización de Rendimiento
    *   5.4 Análisis Espectral
        *   5.4.1 Procesamiento FFT
        *   5.4.2 Detección de Frecuencia
        *   5.4.3 Control de Visualización
        *   5.4.3 Optimización y Rendimiento

# 1. Marco Teórico y Conceptos Fundamentales

## Temas para Marco Teórico:
1. Gitflow
2. Metodología Scrum
3. Dart/Flutter
4. Dependency Injection en Flutter
5. Model View Controller
6. Organización de directorios utilizada
7. Criptografía Asimétrica
8. Pipeline Design Pattern
9. CI/CD en software libre
10. Patrones Observer y Factory en Flutter
11. Redes WiFi y Access Points
12. Protocolos de comunicación Socket y HTTP
13. API REST
14. Transformada Rápida de Fourier
15. Filtros digitales (Butterworth, Moving avg, exponencial, filtfilt para fase, FIR vs IIR, etc)

## 2. Sistema de Inicialización y Configuración Base

### 2.1 Proceso de Inicialización

#### 2.1.1 Configuración Base del Sistema
El proceso de inicialización del sistema establece las condiciones fundamentales para la ejecución de la aplicación:

1.  **Preparación del Framework**
    *   Inicialización del binding de Flutter para garantizar la disponibilidad de servicios nativos
    *   Configuración forzada de orientación landscape para optimizar la visualización de señales
    *   Establecimiento del entorno de ejecución

2.  **Gestión de Permisos**
    El sistema requiere permisos específicos para su funcionamiento en dispositivos Android:
    *   Ubicación permanente: Necesario para operaciones WiFi en segundo plano
    *   Detección de dispositivos WiFi cercanos: Esencial para la conexión con el hardware
    *   Ubicación general: Requerido para funcionalidades de red

#### 2.1.2 Estructura de Navegación
La aplicación implementa un sistema de navegación jerárquico mediante GetMaterialApp:

1.  **Configuración General**
    *   Identificador: 'ARG\_OSCI'
    *   Tema personalizado adaptado a la visualización de señales
    *   Sistema de navegación basado en rutas nombradas

2.  **Jerarquía de Navegación**
    *   Pantalla inicial (SetupScreen): Configuración y conexión
    *   Selección de modo (ModeSelectionScreen): Definición del tipo de análisis
    *   Visualización (GraphScreen): Presentación y análisis de señales

### 2.2 Sistema de Inicialización Jerárquica

#### 2.2.1 Gestión de Dependencias
El sistema implementa una secuencia específica de inicialización para garantizar la disponibilidad de servicios:

1.  **Configuración del Dispositivo**
    *   Registro del `DeviceConfigProvider` como servicio permanente
    *   Establecimiento de parámetros base de operación
    *   Sistema de persistencia de configuración

2.  **Servicios de Comunicación**
    *   Configuración HTTP: Establecimiento de endpoint base (http://192.168.4.1:81)
    *   Configuración Socket: Preparación de canal bidireccional (Puerto 8080)
    *   Sistema de reconexión automática

3.  **Sistema de Procesamiento**
    La inicialización establece una cadena de procesamiento de datos:
    *   Servicio de adquisición vinculado al sistema de comunicación
    *   Proveedor de datos para gestión de estado
    *   Sistema de buffering para procesamiento en tiempo real

4.  **Servicios de Visualización**
    Se establecen los sistemas de representación visual:
    *   Servicio FFT para análisis espectral
    *   Servicio de gráfico temporal
    *   Sistema de control de modo de visualización

5.  **Sistema de Configuración**
    *   Inicialización del servicio de configuración
    *   Establecimiento del proveedor de estados
    *   Preparación de interfaces de usuario

## 3. Sistema de Configuración y Conexión

### 3.1 Establecimiento de Conexión

#### 3.1.1 Modos de Conexión
El sistema soporta dos modos de conexión principales, cada uno adaptado a diferentes escenarios de uso:

1.  **Modo AP Local (Internal AP)**
    *   El dispositivo móvil se conecta directamente al punto de acceso (AP) WiFi generado por el ESP32.
    *   Se utiliza la dirección IP predeterminada (192.168.4.1) para la configuración y comunicación.
    *   Este modo es útil para la configuración inicial o cuando no se dispone de una red WiFi externa.
    *   **Importante:** Este modo se selecciona *después* de la conexión inicial al AP del ESP32 para configuración.

2.  **Modo AP Externo (External AP)**
    *   El ESP32 se conecta a una red WiFi externa existente.
    *   El dispositivo móvil se conecta a la misma red WiFi externa.
    *   Este modo permite el acceso a internet y la operación en redes más amplias.
    *   **Importante:** Este modo se selecciona *después* de la conexión inicial al AP del ESP32 para configuración.

### 3.1.2 Proceso de Conexión al AP Local
El proceso de conexión al AP local se realiza mediante la clase `NetworkInfoService` y sigue los siguientes pasos:

1.  **Conexión al AP:**
    *   Se intenta la conexión al AP "ESP32\_AP" utilizando la librería `wifi_iot`.
    *   Se configura la seguridad como WPA y se proporciona la contraseña "password123".
    *   Se establece un tiempo de espera para la conexión.
    *   Este paso es **inicial** y necesario para configurar el dispositivo, independientemente del modo de operación final.
    *   Se implementa un sistema de reintentos con un máximo de 5 intentos y un delay de 1 segundo entre cada intento.
    *   Se utiliza la función `WiFiForIoTPlugin.connect` para realizar la conexión.
    *   Se verifica la conexión mediante la función `testConnection` que realiza una petición HTTP a la dirección base del ESP32.
2.  **Verificación de la Conexión:**
    *   Se verifica la conexión obteniendo el SSID actual y comparándolo con "ESP32\_AP".
    *   Se realiza una petición HTTP a la dirección base del ESP32 para confirmar la conectividad.
    *   Se utiliza la función `getWifiName` de la librería `network_info_plus` para obtener el SSID actual.
    *   Se utiliza la función `testConnection` de la clase `NetworkInfoService` para realizar la petición HTTP.
3.  **Manejo de Errores:**
    *   Si la conexión falla, se intenta un número limitado de veces.
    *   Si la conexión no se puede establecer, se notifica al usuario y se le pide que se conecte manualmente.
    *   Se muestra un `SnackBar` al usuario indicando que debe conectarse manualmente a la red "ESP32\_AP".
    *   Se registran los errores en la consola en modo debug.
    *   Se implementa un fallback que intenta conectarse a la red mediante un método tradicional de verificación del SSID.

### 3.2 Servicios de Red

#### 3.2.1 NetworkInfoService
La clase `NetworkInfoService` proporciona funcionalidades para obtener información sobre la red y conectarse a ella.

1.  **Obtención de Información de Red:**
    *   `getWifiName()`: Obtiene el nombre (SSID) de la red WiFi actual.
        *   Utiliza la librería `network_info_plus` para obtener el SSID.
        *   Elimina las comillas dobles del SSID.
    *   `getWifiIP()`: Obtiene la dirección IP del dispositivo en la red WiFi actual.
        *   Utiliza la librería `network_info_plus` para obtener la dirección IP.

2.  **Conexión a Redes WiFi (Android):**
    *   `connectToESP32()`: Intenta conectarse a la red WiFi "ESP32\_AP" utilizando la librería `wifi_iot`.
        *   Configura la seguridad como WPA y se proporciona la contraseña "password123".
        *   Establece un tiempo de espera para la conexión.
        *   Realiza múltiples reintentos de conexión.
        *   Verifica la conexión mediante la función `testConnection`.
    *   `connectWithRetries()`: Intenta conectarse a la red WiFi "ESP32\_AP" con un número limitado de reintentos.
        *   Utiliza la función `connectToESP32()` para realizar la conexión.
        *   Implementa un delay entre cada reintento.
    *   `testConnection()`: Tests the connection to the ESP32 by making a GET request.
        *   Realiza una petición HTTP a la dirección base del ESP32.
        *   Verifica la respuesta del servidor.
        *   Maneja los errores de timeout y conexión.

#### 3.2.2 Dependencias
La clase `NetworkInfoService` depende de las siguientes librerías:

*   `network_info_plus`: Para obtener información sobre la red.
*   `wifi_iot`: Para conectarse a redes WiFi (solo en Android).
*   `http`: Para realizar peticiones HTTP y verificar la conexión.
*   `flutter`: Para mostrar el `SnackBar` al usuario.

### 3.3 Interfaz de Usuario

### 3.3.1 Pantalla de Configuración (SetupScreen)
La interfaz principal de configuración implementa:

1.  **Componentes Visuales**
    *   Barra de título personalizada
    *   Botón principal de configuración: "Select AP Mode"
        *   Este botón activa el diálogo `showAPSelectionDialog` al ser presionado, iniciando el proceso de selección de AP.
    *   Diálogos modales para la selección de AP y configuración de red
    *   La pantalla `SetupScreen` es el punto de entrada para la configuración del dispositivo, ofreciendo al usuario la posibilidad de seleccionar entre el modo AP Local y el modo AP Externo.

2.  **Gestión de Estados**
    *   Indicación de progreso mediante diálogos modales
    *   Estados de conexión representados en los diálogos
        *   El estado de la conexión es gestionado por el `SetupProvider` y reflejado en la interfaz de usuario a través del enum `SetupStatus`.
    *   Mensajes de error mostrados en los diálogos
        *   Los mensajes de error, si los hay, se muestran en los diálogos, proporcionando retroalimentación al usuario.
    *   Retroalimentación visual mediante indicadores de carga
    *   La gestión de estados se realiza a través del `SetupProvider`, que controla el flujo de la configuración y la conexión.
        *   La pantalla `SetupScreen` utiliza el `SetupProvider` para gestionar el estado de la conexión y la selección de AP, asegurando que los elementos de la interfaz de usuario reflejen el estado de configuración actual. El `SetupProvider` utiliza un objeto `SetupState` para mantener el `SetupStatus` actual, cualquier mensaje de error y la lista de redes WiFi disponibles.

#### 3.3.2 Diálogos del Sistema
El sistema implementa diálogos especializados:

1.  **Selección de AP (showAPSelectionDialog)**
    *   Muestra un indicador de progreso mientras se conecta al AP local.
    *   Ofrece opciones para seleccionar el modo AP: "Local AP" o "External AP".
    *   Gestiona errores de conexión y muestra mensajes de error.
    *   Utiliza el `SetupProvider` para gestionar el estado de la conexión y la selección del modo AP.
    *   Este diálogo permite al usuario elegir entre conectarse directamente al ESP32 (AP Local) o conectarse a través de una red WiFi externa (AP Externo).

2.  **Configuración de Red (showWiFiNetworkDialog y askForPassword)**
    *   Muestra una lista de redes WiFi disponibles.
    *   Solicita las credenciales (contraseña) para la red seleccionada.
    *   Muestra indicadores de estado durante el proceso de conexión.
    *   Gestiona errores de conexión y ofrece opciones para reintentar o seleccionar otra red.
    *   Utiliza el `SetupProvider` para gestionar el escaneo de redes, la solicitud de contraseñas y el proceso de conexión.
    *   El diálogo `showWiFiNetworkDialog` presenta una lista de redes WiFi disponibles, mientras que `askForPassword` solicita la contraseña para la red seleccionada.

### 3.4 Flujo de Configuración

### 3.4.1 Proceso de Inicialización

Secuencia de configuración inicial:

1.  **Preparación del Sistema**
    *   Carga de componentes
    *   Verificación de permisos
    *   Inicialización de servicios
    *   Establecimiento de estados base
    *   Conexión al AP local mediante la función `connectToLocalAP` del `SetupService`.
        *   Este proceso es iniciado y gestionado por el `SetupProvider`, que actualiza la interfaz de usuario basándose en el enum `SetupStatus`. La función `connectToLocalAP` del `SetupProvider` llama a la función `connectToLocalAP` del `SetupService` y actualiza el `SetupState` de acuerdo con el resultado.
    *   Inicialización de la configuración HTTP y Socket con la dirección IP local.
    *   Obtención de la configuración del dispositivo desde el endpoint `/config` y actualización del `DeviceConfigProvider`.

#### 3.4.2 Flujos de Operación

1.  **Modo AP Local**
    *   Conexión directa
        *   El dispositivo se conecta directamente al punto de acceso (AP) del ESP32.
        *   Se utiliza la función `connectToLocalAP` del `SetupProvider` para gestionar la conexión.
    *   Configuración interna
        *   Se utiliza la dirección IP predeterminada (192.168.4.1) para la configuración.
        *   El `SetupService` inicializa la configuración HTTP y Socket con la dirección IP local.
        *   La función `fetchDeviceConfig` del `SetupService` obtiene la configuración del dispositivo desde el endpoint `/config` y actualiza el `DeviceConfigProvider`.
    *   Verificación de estado
        *   Se verifica la conexión mediante una solicitud HTTP.
    *   Transición a operación
        *   Una vez configurado, el sistema pasa al modo de operación normal.

2.  **Modo AP Externo**
    *   Selección de red
        *   El usuario selecciona una red WiFi externa de la lista disponible.
        *   El diálogo `showWiFiNetworkDialog` muestra las redes disponibles y permite al usuario seleccionar una.
    *   Proceso de credenciales
        *   Se solicitan las credenciales (SSID y contraseña) para la red seleccionada.
        *   El diálogo `askForPassword` solicita la contraseña al usuario.
        *   Las credenciales se encriptan utilizando la clave pública del dispositivo.
        *   La función `encriptWithPublicKey` del `SetupService` realiza el cifrado RSA.
    *   Verificación de conexión
        *   Se verifica la conexión a la red externa mediante una solicitud HTTP.
        *   La función `handleNetworkChangeAndConnect` del `SetupProvider` gestiona la conexión y la verificación.
        *   Se utiliza un sistema de reintentos para asegurar la conexión.
    *   Establecimiento de comunicación
        *   Una vez conectado, el sistema establece la comunicación con el dispositivo.

# 4. Servicios de Comunicación

## 4.1 Sistema de Comunicación HTTP

##### 4.1.1 Arquitectura y Componentes
El sistema de comunicación HTTP implementa una arquitectura en capas que garantiza la robustez y mantenibilidad:

1.  **Configuración Base**
    *   Encapsulamiento de URL base (192.168.4.1:81)
    *   Gestión del ciclo de vida del cliente HTTP
    *   Sistema de serialización para configuración
    *   Mecanismos de reinicialización
    *   Uso de la clase `HttpConfig` para encapsular la URL base y el cliente HTTP.
    *   La clase `HttpConfig` permite la configuración de la URL base y la inyección de un cliente HTTP personalizado, facilitando las pruebas y la adaptación a diferentes entornos.
    *   La URL base se define como una constante en la clase `NetworkInfoService`.

2.  **Capa de Abstracción**
    *   Definición de operaciones HTTP fundamentales
    *   Sistema unificado de gestión de errores
    *   Tipado fuerte de respuestas
    *   Manejo estandarizado de endpoints
    *   Implementación de la interfaz `HttpRepository` para definir las operaciones HTTP.
    *   La interfaz `HttpRepository` define los métodos `get` y `post` para realizar las peticiones HTTP.

3.  **Implementación del Servicio**
    *   Sistema robusto de manejo de errores
    *   Procesamiento automático de JSON
    *   Gestión de cabeceras HTTP
    *   Control de estado de conexión
    *   Implementación de la clase `HttpService` para realizar las operaciones HTTP.
    *   La clase `HttpService` implementa la interfaz `HttpRepository` y utiliza la librería `http` para realizar las peticiones HTTP.
    *   La clase `HttpService` maneja los errores de timeout y conexión.

3. **Implementación del Servicio**
   - Sistema robusto de manejo de errores
   - Procesamiento automático de JSON
   - Gestión de cabeceras HTTP
   - Control de estado de conexión
   - Implementación de la clase `HttpService` para realizar las operaciones HTTP.

##### 4.1.2 Operaciones del Sistema
El servicio HTTP proporciona dos operaciones fundamentales:

1.  **Operaciones GET**
    *   Construcción de URLs parametrizadas
    *   Sistema de validación de respuestas
    *   Decodificación automática de JSON
    *   Manejo estructurado de errores
    *   Uso del método `get` de la clase `HttpService` para realizar las peticiones GET.
    *   El método `get` recibe la URL del endpoint y retorna un `Future<dynamic>` con la respuesta del servidor.
    *   El método `get` maneja los errores de timeout y conexión.

2.  **Operaciones POST**
    *   Serialización automática de cuerpos
    *   Gestión de Content-Type
    *   Sistema de reintentos configurable
    *   Validación de respuestas del servidor
    *   Uso del método `post` de la clase `HttpService` para realizar las peticiones POST.
    *   El método `post` recibe la URL del endpoint y el cuerpo de la petición y retorna un `Future<dynamic>` con la respuesta del servidor.
    *   El método `post` maneja los errores de timeout y conexión.

### 4.2 Sistema de Comunicación Socket

#### 4.2.1 Estructura Principal
El sistema Socket implementa una arquitectura que garantiza la comunicación bidireccional en tiempo real:

1. **Gestión de Conexión**
   - Control reactivo de IP y puerto
   - Sistema observable con GetX
   - Persistencia de configuración
   - Actualización dinámica de parámetros
   - Utiliza la clase `SocketConnection` para encapsular la IP y el puerto, permitiendo actualizaciones reactivas.

2. **Capa de Abstracción**
   - Operaciones Socket fundamentales
   - Gestión del ciclo de vida
   - Sistema de eventos y suscripciones
   - Control de flujo de datos
   - Implementa la interfaz `SocketRepository` para definir las operaciones del socket.

3. **Servicio de Implementación**
   - Gestión de conexiones TCP
   - Sistema de transmisión bidireccional
   - Control de múltiples suscriptores
   - Manejo robusto de desconexiones
   - Implementación de la clase `SocketService` para gestionar la conexión, transmisión y recepción de datos.

### 4.2.2 Sistema de Transmisión de Datos

1. **Envío de Datos**
   - Codificación UTF-8 de mensajes
   - Sistema de terminación de mensajes
   - Gestión de buffer de transmisión
   - Control de errores de escritura
   - Utiliza la codificación UTF-8 para asegurar la compatibilidad con diferentes tipos de datos.

2. **Recepción de Datos**
   - Stream controller en modo broadcast
   - Decodificación UTF-8 de mensajes
   - Sistema de suscripciones múltiple
   - Gestión de cierre de conexiones
   - El `StreamController` en modo broadcast permite que múltiples componentes de la aplicación se suscriban a los datos del socket.

3. **Control de Estado**
   - Monitoreo continuo de conexión
   - Sistema configurable de timeouts
   - Limpieza de recursos del sistema
   - Gestión de reconexiones automáticas

### 4.2.3 Gestión de Eventos y Recursos

1. **Sistema de Suscripción**
   - Registro dinámico de suscriptores
   - Cancelación segura de suscripciones
   - Sistema de propagación de errores
   - Notificaciones de cierre de conexión
   - Permite a los componentes de la aplicación suscribirse a los datos del socket y recibir notificaciones de errores y cierre de conexión.

2. **Gestión de Recursos**
   - Control de buffer de transmisión
   - Sistema de backpressure
   - Gestión eficiente de memoria
   - Limpieza automática de recursos
   - El `SocketService` gestiona un buffer interno para almacenar los datos recibidos del socket y procesarlos en paquetes del tamaño esperado.

## 5. Sistema de Visualización y Procesamiento

### 5.1 Configuración y Adquisición de Datos

1.  **Parámetros Base**
    *   Obtención mediante endpoint /config durante la inicialización
    *   Almacenamiento en `DeviceConfigProvider`:
        *   Frecuencia de muestreo: 1.65MHz
        *   Bits por paquete: 16 bits
        *   Máscara de datos: 0x0FFF
        *   Máscara de canal: 0xF000
        *   Bits efectivos: 9
        *   Muestras por paquete: 8192
        *   Factor de división: 1
    *   Estos parámetros se encapsulan en la clase `DeviceConfig` y se gestionan a través del `DeviceConfigProvider`.
    *   La clase `DeviceConfig` define la estructura de los parámetros de configuración del hardware, mientras que `DeviceConfigProvider` actúa como un proveedor de estado para acceder y modificar estos parámetros de forma reactiva.
    *   La función `DeviceConfig.fromJson` se encarga de parsear la respuesta JSON del endpoint `/config` y crear una instancia de `DeviceConfig`.
    *   En caso de error durante el parseo, se lanza una excepción `FormatException` para indicar que la respuesta del servidor no es válida.
    *   El `DeviceConfigProvider` proporciona acceso reactivo a los parámetros de configuración, permitiendo que otros componentes de la aplicación se actualicen automáticamente cuando cambian los parámetros.
    *   El `DeviceConfigProvider` también proporciona acceso a valores derivados como `dataMaskTrailingZeros` y `channelMaskTrailingZeros`, que se utilizan para optimizar el procesamiento de datos.
    *   Los parámetros de configuración del hardware se pueden modificar a través de la interfaz de usuario en la pantalla de configuración, lo que permite al usuario adaptar el osciloscopio a diferentes tipos de señales.

2.  **Sistema de Escalado**
    *   Factores de escala predefinidos (`VoltageScale`):
        *   Rango Alto: ±400V (factor 800/512)
        *   Rango Medio: ±2V, ±1V (factores 4.0/512, 2.0/512)
        *   Rango Bajo: ±500mV, ±200mV, ±100mV (factores 1/512, 0.4/512, 0.2/512)
    *   Ajuste dinámico de trigger
    *   Propagación de cambios al sistema de visualización
    *   El sistema de escalado permite adaptar la visualización de la señal a diferentes rangos de voltaje, optimizando la precisión y la legibilidad.
    *   Los factores de escala se definen en la enumeración `VoltageScale` y se aplican en el `DataAcquisitionService` para convertir los valores raw a voltajes.
    *   La escala de voltaje se puede seleccionar a través de la interfaz de usuario en la pantalla de configuración, lo que permite al usuario ajustar la visualización de la señal a diferentes rangos de voltaje.
    *   El `UserSettingsProvider` gestiona la selección de la escala de voltaje y notifica al `DataAcquisitionProvider` cuando cambia la escala.


## 5.2 Preprocesamiento y Gestión de Datos

### 5.2.1 Arquitectura de Procesamiento

1.  **Sistema de Isolates**
    *   Isolate de Socket dedicado para comunicación UDP
        *   Responsable de la recepción de datos desde el ESP32 a través de sockets.
        *   Utiliza `SendPort` para enviar los datos recibidos al Isolate de procesamiento.
        *   Implementa un sistema de reconexión automática con un número limitado de reintentos y un delay configurable. Si la reconexión falla, se notifica al usuario y se le redirige a la pantalla de configuración.
    *   Isolate de Procesamiento para análisis en tiempo real
        *   Recibe los datos del Isolate de Socket a través de `StreamController`.
        *   Realiza el procesamiento de la señal, incluyendo filtrado, trigger y cálculo de métricas.
    *   Comunicación mediante `SendPorts` y `StreamController`
        *   `SendPort` permite enviar datos de un Isolate a otro.
        *   `StreamController` permite la gestión de flujos de datos asíncronos.
    *   Sistema de cleanup y gestión de recursos mediante `ReceivePort`
        *   `ReceivePort` permite recibir mensajes de control y finalización desde los Isolates.
        *   Se utiliza para liberar los recursos utilizados por los Isolates al finalizar la ejecución.
    *   El uso de Isolates permite realizar el procesamiento de datos en paralelo, sin bloquear el hilo principal de la aplicación, mejorando la capacidad de respuesta de la interfaz de usuario.
    *   La comunicación entre Isolates se realiza mediante `SendPort` y `StreamController`, lo que permite una gestión eficiente de los datos y minimiza la latencia.

2.  **Pipeline de Datos**
    *   Buffer circular con capacidad 1x el tamaño del chunk (8192 muestras)
    *   Chunks de procesamiento de 8192 muestras
    *   Sistema de trigger en tiempo real
    *   Métricas continuas: frecuencia, valores máx/mín, promedio
    *   El buffer circular permite almacenar los datos recibidos del socket y procesarlos en chunks del tamaño esperado.
    *   El tamaño del chunk se define en la clase `DeviceConfig` y se gestiona a través del `DeviceConfigProvider`.
    *   El pipeline de datos incluye un sistema de gestión de colas que limita el tamaño de la cola para evitar el consumo excesivo de memoria y asegurar un procesamiento en tiempo real.

3.  **Modos de Adquisición**
    *   Modo Normal:
        *   Adquisición continua de datos
        *   Detección múltiple de triggers
        *   Actualización constante de la visualización
        *   Buffer circular con gestión FIFO
    *   Modo Single:
        *   Captura única al detectar trigger
        *   Detención automática post-captura
        *   Buffer extendido (1x chunk size)
        *   Reinicio manual mediante botón
        *   Limpieza de buffer previa a nueva captura
        *   Sistema de espera activa por trigger
    *   Control de modo vía `TriggerMode` enum
    *   Gestión de estados mediante `DataAcquisitionProvider`
    *   Transiciones suaves entre modos
    *   Sistema de notificación de estado
    *   El modo Single implementa un sistema de pausa automática del gráfico una vez que se detecta un trigger, permitiendo al usuario analizar la señal capturada en detalle.

### 5.2.2 Sistema de Trigger

1.  **Modos de Operación**
    *   Histéresis con sensibilidad configurable
        *   Control de rebotes (sensibilidad adaptable en % a los valores máximos y mínimos de la señal)
        *   Bandas de histéresis dinámicas según escala
        *   La histéresis se puede activar o desactivar mediante la propiedad `useHysteresis` del `DataAcquisitionService`.
    *   Filtro Paso Bajo
        *   Pre-filtrado a 50kHz
        *   Coeficientes adaptativos según frecuencia de muestreo
        *   El filtro de paso bajo se puede activar o desactivar mediante la propiedad `useLowPassFilter` del `DataAcquisitionService`.
    *   Detección configurable de flancos
        *   Positivo (rising edge)
        *   Negativo (falling edge)

2.  **Procesamiento de Trigger**
    *   Buffer circular para detección continua
    *   Sistema de ventana post-trigger
    *   Normalización de puntos según trigger
    *   Cálculo de métricas por ventana
    *   El nivel de trigger, el flanco y el modo de trigger se gestionan a través del `DataAcquisitionProvider` y se envían al Isolate de procesamiento mediante mensajes.

### 5.2.3 Sistema de Filtrado

1.  **Tipos de Filtros**
    *   Media móvil con ventana configurable
        *   Implementación mediante convolución directa para eficiencia.
        *   Permite configurar el tamaño de la ventana para suavizar los datos.
    *   Filtro exponencial (alpha: 0.2)
        *   Suavizado exponencial de primer orden.
        *   El parámetro alpha controla la sensibilidad a los cambios recientes en los datos.
    *   Paso bajo con frecuencia de corte variable
        *   Implementado utilizando un filtro Butterworth de segundo orden.
        *   Permite ajustar la frecuencia de corte para eliminar componentes de alta frecuencia no deseados.
        *   Los coeficientes del filtro se recalculan dinámicamente al cambiar la frecuencia de corte.
    *   Sin filtro
        *   No aplica ningún tipo de filtrado a los datos.
        *   Útil para comparar los datos originales con los datos filtrados.

2.  **Gestión de Filtrado**
    *   Aplicación en tiempo real
        *   Los filtros se aplican a los datos a medida que se reciben.
    *   Parámetros configurables dinámicamente
        *   Los parámetros de los filtros se pueden ajustar en tiempo real para adaptarse a las condiciones cambiantes de los datos.
    *   Sistema reactivo de actualización
        *   El sistema se actualiza automáticamente cuando se cambian los parámetros de los filtros.
    *   Optimización de recursos
        *   Los filtros están optimizados para minimizar el uso de recursos de la CPU y la memoria.
    *   Uso de `filtfilt`
        *   Se aplica la función `filtfilt` para un filtrado de fase cero, eliminando el retardo introducido por los filtros.
        *   Se extiende la señal reflejando los datos para minimizar los artefactos en los bordes.

3.  **Detalles de Implementación**
    *   La clase abstracta `FilterType` define la interfaz común para todos los filtros.
    *   Cada filtro implementa el método `apply`, que toma una lista de `DataPoint` y un mapa de parámetros, y devuelve una nueva lista de `DataPoint` filtrados.
    *   Se utiliza un patrón singleton para las clases de filtro `MovingAverageFilter`, `ExponentialFilter` y `NoFilter`.
    *   El filtro `LowPassFilter` utiliza un filtro Butterworth de segundo orden, cuyos coeficientes se calculan dinámicamente en función de la frecuencia de corte y la frecuencia de muestreo.
    *   Se incluye la función `filtfilt` para aplicar el filtro hacia adelante y hacia atrás, eliminando el retardo de fase.

### 5.2.4 Sistema de Escalado

1.  **Escalas de Voltaje**
    *   Rangos predefinidos:
        *   Alto: ±400V (factor 800/512)
        *   Medio: ±2V, ±1V (factores 4.0/512, 2.0/512)
        *   Bajo: ±500mV, ±200mV, ±100mV
    *   Ajuste dinámico de trigger
    *   Propagación de cambios al sistema

2.  **Control de Escalas**
    *   Escala temporal según frecuencia
    *   Escala de valores según rango
    *   Sistema de autoajuste
    *   Normalización de coordenadas

### 5.2.5 Métricas y Autoajuste

1.  **Cálculo de Métricas**
    *   Frecuencia mediante intervalos entre triggers
    *   Valores máximos y mínimos por ventana
    *   Promedio móvil de señal
    *   Actualización continua mediante streams

2.  **Sistema de Autoajuste**
    *   Ajuste temporal:
        *   Visualización de 3 períodos
        *   Adaptación según ancho de pantalla
    *   Ajuste de amplitud:
        *   Normalización según valor máximo
        *   Centrado de trigger
        *   Limitación según rango de voltaje

### 5.2.6 Sistema de Estado

1.  **Gestión Reactiva**
    *   Variables observables para parámetros críticos
    *   Sistema de suscripción a streams
    *   Propagación de cambios
    *   Control mediante GetX

2.  **Control de Flujo**
    *   Sistema de pausa/reanudación
    *   Gestión de recursos
    *   Cleanup automático
    *   Manejo de errores robusto

### 5.3 Visualización Temporal

#### 5.3.1 Arquitectura de Visualización

1.  **Modelo de Datos**
    *   Flujo de puntos de datos mediante Stream broadcast
    *   Sistema de pausa/reanudación de visualización
    *   Control de distancia entre muestras
    *   Gestión de recursos y memoria
    *   El `OscilloscopeChartService` gestiona el flujo de datos mediante un `StreamController` en modo broadcast, permitiendo que múltiples componentes de la aplicación se suscriban a los datos del gráfico.
    *   El `OscilloscopeChartProvider` se suscribe al `dataStream` del `OscilloscopeChartService` y actualiza la lista de `DataPoint` que se utilizan para renderizar el gráfico.
    *   Se implementa un sistema de pausa/reanudación de la visualización que permite al usuario detener y reanudar la actualización del gráfico.
    *   El `OscilloscopeChartProvider` controla el estado de pausa/reanudación y notifica al `OscilloscopeChartService` cuando cambia el estado.
    *   El `OscilloscopeChart` widget utiliza el `OscilloscopeChartProvider` para acceder a los datos y al estado de la visualización.
    *   El `OscilloscopeChartPainter` utiliza los parámetros de configuración del hardware proporcionados por el `DeviceConfigProvider` para calcular la escala de tiempo y la escala de valor.

2.  **Sistema de Transformación**
    *   Conversión entre dominios tiempo-pantalla
    *   Cálculo dinámico de distancia entre muestras
    *   Ajuste según frecuencia de muestreo
    *   Sistema de coordenadas adaptativo
    *   El `OscilloscopeChartPainter` se encarga de realizar la conversión entre los dominios de tiempo y pantalla, utilizando las escalas de tiempo y valor proporcionadas por el `OscilloscopeChartProvider`.
    *   Se implementa un sistema de coordenadas adaptativo que permite ajustar la visualización de la señal a diferentes rangos de voltaje y frecuencias de muestreo.
    *   El `OscilloscopeChartPainter` utiliza las funciones `_domainToScreenX` y `_domainToScreenY` para realizar la conversión entre los dominios de tiempo y pantalla.
    *   Se implementa un sistema de clipping para evitar que la señal se dibuje fuera de los límites del gráfico.

#### 5.3.2 Gestión de Estado (LineChartProvider)

1.  **Control de Vista**
    *   Sistema de escalas independientes:
        *   Escala temporal con factor base 1.0
        *   Escala de valores con factor base 1.0
    *   Offsets bidimensionales:
        *   Desplazamiento horizontal para tiempo
        *   Desplazamiento vertical para amplitud
    *   Sistema de zoom con punto focal
    *   El `OscilloscopeChartProvider` gestiona las escalas de tiempo y valor de forma independiente, permitiendo al usuario ajustar la visualización de la señal en ambos ejes.
    *   Se implementan offsets bidimensionales que permiten al usuario desplazar la señal en los ejes horizontal y vertical.
    *   Se implementa un sistema de zoom con punto focal que permite al usuario hacer zoom en una región específica de la señal.
    *   El `OscilloscopeChartProvider` utiliza variables reactivas (`Rx<T>`) para gestionar el estado de la visualización y notificar a los componentes de la interfaz de usuario sobre los cambios.
    *   El `UserSettings` widget proporciona controles para ajustar las escalas de tiempo y valor, así como los offsets horizontal y vertical.

2.  **Interacción de Usuario**
    *   Control mediante gestos:
        *   Zoom multitáctil con preservación de punto focal
        *   Arrastre para desplazamiento
        *   Doble tap para reset
    *   Control mediante periféricos:
        *   Rueda de mouse para zoom
        *   Teclado para navegación fina
        *   Modificadores para control específico de ejes
    *   El `_ChartGestureHandler` se encarga de gestionar los gestos del usuario y actualizar el estado de la visualización en el `OscilloscopeChartProvider`.
    *   Se implementa un sistema de zoom multitáctil que permite al usuario hacer zoom en la señal utilizando dos dedos.
    *   Se implementa un sistema de arrastre que permite al usuario desplazar la señal en los ejes horizontal y vertical.
    *   Se implementa un sistema de control mediante periféricos que permite al usuario ajustar la visualización de la señal utilizando el teclado y el ratón.
    *   Se utilizan modificadores del teclado (Ctrl, Shift) para permitir al usuario controlar los ejes de forma independiente.
    *   El `_ChartGestureHandler` utiliza las escalas de tiempo y valor proporcionadas por el `OscilloscopeChartProvider` para calcular la transformación de los gestos del usuario.

#### 5.3.3 Procesamiento de Datos

1.  **Sistema de Streaming**
    *   Suscripción al flujo de datos principal
    *   Transformación de puntos según configuración
    *   Control de estado de pausa
    *   Gestión de recursos del sistema
    *   El `OscilloscopeChartService` se suscribe al flujo de datos principal proporcionado por el `DataAcquisitionProvider` y transforma los puntos de datos según la configuración actual.
    *   Se implementa un sistema de control de estado de pausa que permite al usuario detener y reanudar la visualización de la señal.
    *   El `OscilloscopeChartService` gestiona los recursos del sistema y libera los recursos utilizados al finalizar la ejecución.

2.  **Control de Flujo**
    *   Sistema de pausa/reanudación
    *   Cancelación segura de suscripciones
    *   Limpieza automática de recursos
    *   Manejo de ciclo de vida
    *   El `OscilloscopeChartService` implementa un sistema de pausa/reanudación que permite al usuario detener y reanudar la visualización de la señal.
    *   Se implementa un sistema de cancelación segura de suscripciones que permite liberar los recursos utilizados por las suscripciones al finalizar la ejecución.
    *   El `OscilloscopeChartService` gestiona el ciclo de vida de los componentes y libera los recursos utilizados al finalizar la ejecución.

#### 5.3.4 Optimización de Rendimiento

1.  **Gestión de Memoria**
    *   Sistema de buffering eficiente
    *   Limpieza proactiva de recursos
    *   Control de suscripciones
    *   Manejo de ciclo de vida
    *   El `OscilloscopeChartService` utiliza un sistema de buffering eficiente para gestionar los datos recibidos del `DataAcquisitionProvider`.
    *   Se implementa un sistema de limpieza proactiva de recursos que permite liberar los recursos utilizados por los componentes que ya no son necesarios.
    *   El `OscilloscopeChartService` controla las suscripciones a los flujos de datos y libera los recursos utilizados al finalizar la ejecución.
    *   Se gestiona el ciclo de vida de los componentes para asegurar que los recursos se liberan correctamente al finalizar la ejecución.

2.  **Renderizado Eficiente**
    *   Sistema de coordenadas optimizado
    *   Transformación selectiva de puntos
    *   Actualización parcial de vista
    *   Control de recursos gráficos
    *   El `OscilloscopeChartPainter` utiliza un sistema de coordenadas optimizado para renderizar la señal de forma eficiente.
    *   Se implementa una transformación selectiva de puntos que permite dibujar solo los puntos que son visibles en la pantalla.
    *   Se realiza una actualización parcial de la vista que permite redibujar solo las regiones de la pantalla que han cambiado.
    *   El `OscilloscopeChartPainter` controla los recursos gráficos y libera los recursos utilizados al finalizar la ejecución.

### 5.4 Análisis Espectral

#### 5.4.1 Procesamiento FFT

1.  **Adquisición de Datos**
    *   Buffer dinámico de puntos de entrada
    *   Tamaño de bloque configurable (8192 * 2 muestras)
    *   Sistema de pausa/reanudación
    *   Control de sobrecarga de procesamiento
    *   El `FFTChartService` recibe los datos del `DataAcquisitionProvider` a través de un stream.
    *   Se utiliza un buffer dinámico para almacenar los puntos de entrada y procesarlos en bloques del tamaño configurado.
    *   Se implementa un sistema de pausa/reanudación para controlar el procesamiento de datos.
    *   El `UserSettingsProvider` gestiona la selección del modo de visualización (Osciloscopio o FFT) y notifica al `FFTChartService` cuando cambia el modo.

2.  **Algoritmo FFT**
    *   Implementación optimizada con SIMD
    *   Permutación de bits para ordenamiento
    *   Procesamiento en bloques de 4 elementos
    *   Cálculo de magnitudes y fases
    *   Normalización automática de resultados
    *   Se utiliza una implementación optimizada del algoritmo FFT con SIMD para mejorar el rendimiento.
    *   Se realiza una permutación de bits para ordenar los datos antes del procesamiento.
    *   El procesamiento se realiza en bloques de 4 elementos para aprovechar las capacidades SIMD.
    *   Se calculan las magnitudes y fases de los componentes de frecuencia.
    *   Los resultados se normalizan automáticamente para facilitar su interpretación.

3.  **Post-procesamiento**
    *   Conversión a decibeles (dB)
    *   Resolución frecuencial dinámica
    *   Límite en frecuencia de Nyquist
    *   Sistema de detección de picos
    *   Los resultados del FFT se convierten a decibeles (dB) para facilitar la visualización del espectro.
    *   Se calcula la resolución frecuencial dinámica en función de la frecuencia de muestreo y el tamaño del bloque.
    *   Se aplica un límite en la frecuencia de Nyquist para evitar el aliasing.
    *   Se implementa un sistema de detección de picos para identificar las frecuencias dominantes.

### 5.4.2 Detección de Frecuencia

1.  **Análisis de Picos**
    *   Umbral mínimo de -160 dB
    *   Detección de pendiente positiva
    *   Búsqueda de máximos locales
    *   Validación de magnitudes
    *   Se aplica un umbral mínimo de -160 dB para eliminar el ruido de fondo.
    *   Se detecta la pendiente positiva para identificar los picos ascendentes.
    *   Se realiza una búsqueda de máximos locales para encontrar los picos más prominentes.
    *   Se validan las magnitudes de los picos para asegurar que sean significativas.

2.  **Cálculo de Frecuencia**
    *   Resolución basada en frecuencia de muestreo
    *   Sistema de ventana deslizante
    *   Filtrado de señales espurias
    *   Actualización en tiempo real
    *   Se calcula la resolución basada en la frecuencia de muestreo para determinar la precisión de la medición de frecuencia.
    *   Se utiliza un sistema de ventana deslizante para suavizar la señal y reducir el ruido.
    *   Se filtran las señales espurias para eliminar las frecuencias no deseadas.
    *   La frecuencia se actualiza en tiempo real para reflejar los cambios en la señal.

### 5.4.3 Control de Visualización

1.  **Gestión de Estado**
    *   Sistema reactivo de puntos FFT
    *   Control de escalas bidimensional
    *   Sistema de pausa/reproducción
    *   Actualización automática de frecuencia
    *   El `FFTChartProvider` gestiona el estado de la visualización del gráfico FFT de forma reactiva.
    *   Se implementa un control de escalas bidimensional para ajustar la visualización en los ejes de frecuencia y amplitud.
    *   Se proporciona un sistema de pausa/reproducción para controlar la actualización del gráfico.
    *   La frecuencia se actualiza automáticamente para reflejar los cambios en la señal.

2.  **Sistema de Zoom**
    *   Zoom multitáctil con factor cuadrático
    *   Preservación de punto focal
    *   Escalas independientes por eje
    *   Sistema de límites dinámicos
    *   Se implementa un sistema de zoom multitáctil con factor cuadrático para facilitar la ampliación de la visualización.
    *   Se preserva el punto focal durante el zoom para mantener la atención en la región de interés.
    *   Se utilizan escalas independientes por eje para ajustar la visualización en los ejes de frecuencia y amplitud de forma independiente.
    *   Se implementa un sistema de límites dinámicos para evitar la ampliación excesiva de la visualización.

3.  **Control de Vista**
    *   Desplazamiento bidimensional
    *   Sistema de incremento/decremento fino
    *   Autoajuste según frecuencia máxima
    *   Gestión de timers de actualización
    *   Se implementa un desplazamiento bidimensional para facilitar la navegación por el gráfico.
    *   Se proporciona un sistema de incremento/decremento fino para ajustar la visualización con precisión.
    *   Se realiza un autoajuste según la frecuencia máxima para optimizar la visualización.
    *   Se gestionan los timers de actualización para controlar la frecuencia de actualización del gráfico.

### 5.4.3 Optimización y Rendimiento

1.  **Gestión de Recursos**
    *   Control de memoria mediante buffering
    *   Limpieza automática de datos
    *   Sistema de pausa en segundo plano
    *   Cancelación segura de suscripciones
    *   Se controla la memoria mediante un sistema de buffering para evitar el consumo excesivo de recursos.
    *   Se realiza una limpieza automática de datos para liberar memoria.
    *   Se implementa un sistema de pausa en segundo plano para reducir el consumo de recursos cuando el gráfico no está visible.
    *   Se cancelan las suscripciones de forma segura para evitar fugas de memoria.

2.  **Control de Flujo**
    *   Sistema de bloqueo durante procesamiento
    *   Gestión de sobrecarga de datos
    *   Control de estado de pausa
    *   Manejo de errores robusto
    *   Se implementa un sistema de bloqueo durante el procesamiento para evitar la corrupción de datos.
    *   Se gestiona la sobrecarga de datos para evitar la pérdida de información.
    *   Se controla el estado de pausa para detener el procesamiento cuando no es necesario.
    *   Se implementa un manejo de errores robusto para garantizar la estabilidad de la aplicación.

3.  **Renderizado Eficiente**
    *   Actualización selectiva de vista
    *   Sistema de doble buffer
    *   Control de resolución adaptativo
    *   Optimización de recursos gráficos
    *   Se realiza una actualización selectiva de la vista para reducir el tiempo de renderizado.
    *   Se utiliza un sistema de doble buffer para evitar el parpadeo durante la actualización del gráfico.
    *   Se controla la resolución de forma adaptativa para optimizar el rendimiento en diferentes dispositivos.
    *   Se optimizan los recursos gráficos para reducir el consumo de memoria y mejorar el rendimiento.

## 5.5 Sistema de Adquisición y Procesamiento

### 5.5.1 Arquitectura de Procesamiento

1.  **Sistema de Isolates**
    *   Isolate de Socket dedicado para comunicación de red
        *   Responsable de la recepción de datos desde el ESP32 a través de sockets.
        *   Utiliza `SendPort` para enviar los datos recibidos al Isolate de procesamiento.
        *   Implementa un sistema de reconexión automática con un número limitado de reintentos y un delay configurable. Si la reconexión falla, se notifica al usuario y se le redirige a la pantalla de configuración.
    *   Isolate de Procesamiento para análisis en tiempo real
        *   Recibe los datos del Isolate de Socket a través de `StreamController`.
        *   Realiza el procesamiento de la señal, incluyendo filtrado, trigger y cálculo de métricas.
    *   Comunicación mediante `SendPorts` y `StreamController`
        *   `SendPort` permite enviar datos de un Isolate a otro.
        *   `StreamController` permite la gestión de flujos de datos asíncronos.
    *   Sistema de cleanup y gestión de recursos mediante `ReceivePort`
        *   `ReceivePort` permite recibir mensajes de control y finalización desde los Isolates.
        *   Se utiliza para liberar los recursos utilizados por los Isolates al finalizar la ejecución.
    *   El uso de Isolates permite realizar el procesamiento de datos en paralelo, sin bloquear el hilo principal de la aplicación, mejorando la capacidad de respuesta de la interfaz de usuario.
    *   La comunicación entre Isolates se realiza mediante `SendPort` y `StreamController`, lo que permite una gestión eficiente de los datos y minimiza la latencia.

2.  **Pipeline de Datos**
    *   Buffer circular con capacidad 1x el tamaño del chunk (8192 muestras)
    *   Chunks de procesamiento de 8192 muestras
    *   Sistema de trigger en tiempo real
    *   Métricas continuas: frecuencia, valores máx/mín, promedio
    *   El buffer circular permite almacenar los datos recibidos del socket y procesarlos en chunks del tamaño esperado.
    *   El tamaño del chunk se define en la clase `DeviceConfig` y se gestiona a través del `DeviceConfigProvider`.
    *   El pipeline de datos incluye un sistema de gestión de colas que limita el tamaño de la cola para evitar el consumo excesivo de memoria y asegurar un procesamiento en tiempo real.

3.  **Modos de Adquisición**
    *   Modo Normal:
        *   Adquisición continua de datos
        *   Detección múltiple de triggers
        *   Actualización constante de la visualización
        *   Buffer circular con gestión FIFO
    *   Modo Single:
        *   Captura única al detectar trigger
        *   Detención automática post-captura
        *   Buffer extendido (1x chunk size)
        *   Reinicio manual mediante botón
        *   Limpieza de buffer previa a nueva captura
        *   Sistema de espera activa por trigger
    *   Control de modo vía `TriggerMode` enum
    *   Gestión de estados mediante `DataAcquisitionProvider`
    *   Transiciones suaves entre modos
    *   Sistema de notificación de estado
    *   El modo Single implementa un sistema de pausa automática del gráfico una vez que se detecta un trigger, permitiendo al usuario analizar la señal capturada en detalle.

### 5.5.2 Procesamiento de Señales

1.  **Decodificación de Datos**
    *   Lectura de paquetes de 16 bits en little-endian
    *   Extracción de datos mediante máscara 0x0FFF
    *   Separación de canal mediante shift dinámico
    *   Conversión a coordenadas normalizadas
    *   La decodificación de datos se realiza en el Isolate de procesamiento, para evitar bloquear el hilo principal de la aplicación.
    *   La extracción de datos se realiza mediante máscaras definidas en la clase `DeviceConfig`.
    *   Se implementa un sistema de detección de errores durante la decodificación de datos, que permite identificar y corregir posibles errores en la transmisión.

2.  **Sistema de Trigger**
    *   Dos modos de operación:
        *   Histéresis: Control de rebotes con sensibilidad adaptable en % a los valores máximos y mínimos de la señal
        *   Filtro Paso Bajo: Pre-filtrado a 50kHz
    *   Detección de flancos con buffer circular
    *   Ventana temporal configurable post-trigger
    *   El sistema de trigger permite sincronizar la visualización de la señal con un evento específico.
    *   El nivel de trigger, el flanco y el modo de trigger se gestionan a través del `DataAcquisitionProvider` y se envían al Isolate de procesamiento mediante mensajes.
    *   El sistema de trigger implementa un filtro de histéresis para evitar triggers falsos debido al ruido en la señal, mejorando la estabilidad de la visualización.
    *   Se ha añadido la posibilidad de desactivar el filtro de histéresis y el filtro de paso bajo mediante las propiedades `useHysteresis` y `useLowPassFilter` del `DataAcquisitionService`, permitiendo una mayor flexibilidad en la configuración del trigger.

### 5.5.3 Control de Flujo

1.  **Gestión de Estado**
    *   Control reactivo mediante GetX
    *   Variables observables para parámetros críticos:
        *   Nivel de trigger
        *   Escalas de tiempo/valor
        *   Modo de filtrado
        *   Estado de adquisición
        *   Uso de histéresis
        *   Uso de filtro de paso bajo
        *   Modo de trigger (Normal/Single)
    *   Sistema de pausa/reanudación
    *   El estado de la adquisición se gestiona de forma reactiva mediante GetX, permitiendo que la interfaz de usuario se actualice automáticamente cuando cambian los parámetros.
    *   El `DataAcquisitionProvider` utiliza variables reactivas (`Rx<T>`) para gestionar el estado de la adquisición y el procesamiento de datos.
    *   Los cambios en las variables reactivas se propagan automáticamente a los componentes de la interfaz de usuario que están suscritos a ellas.
    *   Se utiliza el patrón Observer para notificar a los componentes de la interfaz de usuario sobre los cambios en el estado de la adquisición.
    *   El `UserSettingsProvider` gestiona la selección del modo de visualización (Osciloscopio o FFT) y notifica al `DataAcquisitionProvider` cuando cambia el modo.
    *   El `UserSettingsProvider` también gestiona la selección de la fuente de frecuencia (dominio del tiempo o FFT) y actualiza la visualización de la frecuencia en la interfaz de usuario.

2.  **Procesamiento de Datos**
    *   Pipeline de filtrado configurable:
        *   Media móvil con ventana ajustable
        *   Filtro exponencial (alpha: 0.2)
        *   Paso bajo con frecuencia de corte variable
    *   Sistema de autoset para escalas
    *   Control de flujo adaptativo según modo
    *   Gestión específica para modo single:
        *   Buffer circular dedicado
        *   Procesamiento post-trigger
        *   Control de finalización
        *   Sistema de reinicio
    *   El pipeline de filtrado se aplica en tiempo real y permite al usuario seleccionar el tipo de filtro y ajustar sus parámetros para optimizar la visualización de la señal.
    *   El `DataAcquisitionProvider` gestiona el pipeline de filtrado y aplica los filtros seleccionados a los datos recibidos del Isolate de procesamiento.
    *   Se utilizan los parámetros configurables para ajustar el comportamiento de los filtros en tiempo real.
    *   Se implementa un sistema de autoajuste para optimizar la visualización de la señal en función de las características de la señal.
    *   Los parámetros de los filtros se pueden ajustar a través de la interfaz de usuario en la pantalla de configuración, lo que permite al usuario adaptar el procesamiento de datos a diferentes tipos de señales.
    *   El `UserSettings` widget proporciona controles para ajustar los parámetros de los filtros, como el tamaño de la ventana para el filtro de media móvil, el valor alpha para el filtro exponencial y la frecuencia de corte para el filtro de paso bajo.
    *   El `OscilloscopeChartProvider` utiliza los resultados del autoajuste para ajustar las escalas de tiempo y valor del gráfico.

### 5.5.4 Gestión de Recursos

1.  **Control de Memoria**
    *   Sistema de buffering circular eficiente
    *   Límites dinámicos para cola de datos
    *   Cleanup automático de datos antiguos
    *   Gestión de suscripciones y streams
    *   El sistema de buffering circular permite almacenar los datos recibidos del socket y procesarlos de forma eficiente, minimizando el consumo de memoria.
    *   Se implementa un sistema de gestión de memoria que libera los recursos utilizados por los Isolates al finalizar la ejecución, evitando fugas de memoria.
    *   El `DataAcquisitionProvider` gestiona las suscripciones a los streams de datos y libera los recursos utilizados al finalizar la ejecución.
    *   Se utiliza el método `onClose` para liberar los recursos utilizados por el `DataAcquisitionProvider` al finalizar la ejecución.
    *   El `UserSettingsProvider` también implementa el método `onClose` para liberar los recursos utilizados por el proveedor al finalizar la ejecución.

2.  **Manejo de Errores**
    *   Sistema de timeouts configurables
    *   Reconexión automática con delay de 5 segundos
    *   Cleanup seguro de isolates y recursos
    *   Propagación estructurada de errores
    *   El sistema de manejo de errores permite detectar y recuperarse de errores de conexión y procesamiento, garantizando la estabilidad de la aplicación.
    *   Se ha mejorado el manejo de errores durante la conexión al socket, proporcionando información más detallada sobre la causa del error y facilitando la resolución de problemas.
    *   El `DataAcquisitionProvider` gestiona los errores de conexión y procesamiento y notifica al usuario sobre los errores.
    *   Se utiliza el método `_handleConnectionError` del `DataAcquisitionService` para gestionar los errores de conexión.

#### 5.5.5 Métricas y Autoajuste

1.  **Cálculo de Métricas**
    *   Frecuencia mediante intervalos entre triggers
    *   Valores máximos y mínimos de señal
    *   Promedio móvil de señal
    *   Actualización continua mediante streams
    *   El cálculo de métricas permite obtener información sobre la señal en tiempo real, facilitando el análisis y la interpretación de los datos.
    *   El `DataAcquisitionProvider` recibe las métricas calculadas por el `DataAcquisitionService` a través de streams y las expone a los componentes de la interfaz de usuario.
    *   El `UserSettingsProvider` gestiona la selección de la fuente de frecuencia (dominio del tiempo o FFT) y actualiza la visualización de la frecuencia en la interfaz de usuario.

2.  **Sistema de Autoajuste**
    *   Ajuste temporal:
        *   Visualización de 3 períodos
        *   Adaptación según ancho de pantalla
    *   Ajuste de amplitud:
        *   Normalización según valor máximo
        *   Centrado de trigger
        *   Limitación según rango de voltaje
    *   El sistema de autoajuste permite optimizar la visualización de la señal de forma automática, adaptándola a diferentes tipos de señales y condiciones de visualización.
    *   El sistema de autoajuste se basa en las métricas calculadas en tiempo real y permite adaptar la visualización a diferentes tipos de señales.
    *   Se ha añadido un sistema de autoajuste del nivel de trigger, que permite centrar la señal en la pantalla de forma automática, mejorando la experiencia del usuario.
    *   El `DataAcquisitionProvider` implementa el sistema de autoajuste y ajusta los parámetros de visualización en función de las métricas calculadas.
    *   Se utiliza el método `autoset` del `DataAcquisitionService` para realizar el autoajuste.
    *   El `OscilloscopeChartProvider` utiliza los resultados del autoajuste para ajustar las escalas de tiempo y valor del gráfico.

### 5.5.6 Comunicación entre Isolates

1.  **Socket Isolate**
    *   Recibe datos del ESP32 a través de sockets.
    *   Envía los datos al Processing Isolate mediante `SendPort`.
    *   Implementa un sistema de reconexión automática.
    *   Gestiona errores de conexión y notifica al usuario.

2.  **Processing Isolate**
    *   Recibe datos del Socket Isolate a través de `StreamController`.
    *   Realiza el procesamiento de la señal (filtrado, trigger, métricas).
    *   Envía los datos procesados al hilo principal mediante `SendPort`.
    *   Gestiona el estado de la adquisición y el trigger.

3.  **Hilo Principal**
    *   Recibe los datos procesados del Processing Isolate.
    *   Actualiza la interfaz de usuario con los datos recibidos.
    *   Controla el estado de la adquisición y el trigger.
    *   Gestiona la configuración de la aplicación.
    *   El `DataAcquisitionProvider` actúa como intermediario entre el hilo principal y los Isolates, gestionando la comunicación y la transferencia de datos.
    *   Se utilizan `StreamController` y `SendPort` para la comunicación entre los Isolates y el hilo principal.

### 5.5.7 Hilo de Interfaz de Usuario (UI)**

1.  **Recepción de Datos**
    *   Recibe los datos procesados del Isolate de procesamiento a través de `StreamController`.
    *   Actualiza la visualización de la señal en tiempo real.
    *   Gestiona el estado de la interfaz de usuario (UI).
    *   El `DataAcquisitionProvider` proporciona los datos procesados a los componentes de la interfaz de usuario a través de streams.
    *   Los componentes de la interfaz de usuario se suscriben a los streams de datos y se actualizan automáticamente cuando cambian los datos.

2.  **Control de la Adquisición**
    *   Permite al usuario iniciar y detener la adquisición de datos.
    *   Permite al usuario configurar los parámetros de la adquisición (escala, trigger, filtros).
    *   Envía los comandos de control al Isolate de procesamiento a través de `SendPort`.
    *   El `DataAcquisitionProvider` proporciona métodos para iniciar y detener la adquisición de datos y para configurar los parámetros de la adquisición.
    *   Los componentes de la interfaz de usuario llaman a estos métodos para controlar la adquisición de datos.

3.  **Visualización de Métricas**
    *   Muestra las métricas calculadas en tiempo real (frecuencia, valores máximos y mínimos).
    *   Permite al usuario ajustar la escala de la visualización.
    *   Proporciona herramientas de análisis de la señal (zoom, desplazamiento).
    *   El `DataAcquisitionProvider` proporciona las métricas calculadas a los componentes de la interfaz de usuario a través de variables reactivas.
    *   Los componentes de la interfaz de usuario se suscriben a las variables reactivas y se actualizan automáticamente cuando cambian las métricas.

### 5.5.8 Gestión de Errores y Reconexión

1.  **Detección de Errores**
    *   El `DataAcquisitionService` implementa un sistema de detección de errores que permite identificar y recuperarse de errores de conexión y procesamiento.
    *   Se utilizan timeouts configurables para detectar errores de conexión.
    *   Se implementa un sistema de reconexión automática con un número limitado de reintentos y un delay configurable.

2.  **Reconexión Automática**
    *   Si la conexión al socket se pierde, el `DataAcquisitionService` intenta reconectarse automáticamente.
    *   Se utiliza un número limitado de reintentos para evitar bucles infinitos.
    *   Si la reconexión falla, se notifica al usuario y se le redirige a la pantalla de configuración.

3.  **Notificación al Usuario**
    *   Se muestra un `SnackBar` al usuario para notificarle sobre los errores de conexión y el estado de la reconexión.
    *   Se redirige al usuario a la pantalla de configuración si la reconexión automática falla.
    *   El `DataAcquisitionProvider` gestiona la notificación al usuario sobre los errores de conexión y el estado de la reconexión.
    *   Se utiliza el servicio de snackbar de GetX para mostrar las notificaciones al usuario.
    *   El `SetupProvider` gestiona la conexión al AP local y la conexión a redes WiFi externas, y notifica al usuario sobre los errores de conexión.