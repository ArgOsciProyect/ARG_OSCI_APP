# arg_osci_app

## Descripción General

Este proyecto consiste en el desarrollo de una aplicación de osciloscopio, diseñada en **Flutter** y que se comunica con un dispositivo **ESP32** mediante **Wi-Fi**. La aplicación permite la adquisición de datos en tiempo real con capacidades de visualización y análisis, y permite al usuario seleccionar modos de funcionamiento, ajustar configuraciones de gráficos y recibir alertas de conexión.

## Requerimientos de producto

- REQ 1: Interfaz de comunicacion inalambrica
- REQ 2: Funcionalidades basicas de un osciloscopio
- REQ 3: Que sea facil de reproducir con un bajo costo
- REQ 4: Que sea de codigo y hardware abierto
- REQ 5: Adaptable a otras tecnologias
- REQ 6: Mantenible a largo plazo

## Requerimientos APP
### Requerimientos funcionales
- REQFAPP1: Comunicacion de control por Wi-Fi (REQ1)
- REQFAPP2: Comunicacion de datos por Wi-Fi (REQ1)
- REQFAPP3: Configuracion inicial por Wi-Fi (REQ1)
- REQFAPP4: Graficador con escalas variables (REQ2)
- REQFAPP5: Opcion de filtro digital configurable por el usuario (REQ2)
- REQFAPP6: Trigger digital (REQ2)
- REQFAPP7: Tolerancia de mas de un dispositivo para multiples entradas (REQ2 - REQ5)
- REQFAPP8: Multiplataforma (REQ3-REQ5)
- REQFAPP9: Las tecnologias utilizadas deben ser de codigo abierto (REQ4)

### Requerimientos no funcionales
- REQNFAPP1: Interfaz similar a un osciloscopio de mercado (REQ2)
- REQNFAPP2: Aplicar principios SOLID (REQ5 - REQ6)

### Funcionalidad Principal

La aplicación permite la interacción con el dispositivo ESP32 de las siguientes maneras:
- **Wi-Fi**: Para realizar la configuración inicial y posteriormente recibir los datos de adquisición de señales en tiempo real.

### Sistemas operativos soportados

La aplicación funcionará en Android, Linux y Windows.

### Flujo de Funcionamiento

1. **Conexión al AP de la ESP32**: El usuario inicialmente se conectará a un AP generado por la ESP32 para realizar la configuración inicial.
2. **Configuración de Red Wi-Fi**: El usuario elige si el ESP32 funcionará en modo **AP (Access Point)** (opción recomendada, pero que implica la pérdida de acceso a internet) o si usará una red AP existente (más inestable). 

3. **Adquisición y Procesamiento de Datos**: Una vez establecida la conexión Wi-Fi, el usuario accede al menú principal, donde puede seleccionar modos como "Osciloscopio" o "Analizador de Espectro". Los datos adquiridos vía Wi-Fi son procesados en la app, lo que puede incluir formato, compresión o transformaciones FFT para visualización en frecuencia.
4. **Visualización de Datos**: La aplicación ofrece varios modos de visualización, incluyendo:
    - **Gráfico en Tiempo**: Para visualizar la señal en el dominio temporal.
    - **Gráfico en Frecuencia**: Para visualizar la señal en el dominio de la frecuencia (requiere cálculo de FFT).

### Componentes Principales

1. **Control/Comunicación (WiFi)**:
    - Gestiona la configuración y el cambio de modos del dispositivo desde la app.
    - Permite recibir ajustes específicos (como escala de voltaje) desde el dispositivo.
    - Implementación en `SocketService`, que también maneja el intercambio de claves RSA y el cifrado AES.
2. **Adquisición de Datos (Wi-Fi)**:
    - Responsable de recibir datos en tiempo real desde el ESP32 en modo AP o red externa.
    - La comunicación de credenciales y datos se maneja de forma segura mediante cifrado AES.
    - Se implementa en `SocketService` y `SetupProvider`, que facilitan la conexión y mantienen la estabilidad de la misma.
3. **Procesamiento de Datos**:
    - Da formato a los datos recibidos y aplica transformaciones como compresión o cálculo de FFT.
    - `DataProcessingService` se encarga de este procesamiento, permitiendo que los datos estén listos para su visualización en la interfaz de usuario.
4. **Visualización de Datos**:
    - Ofrece varios modos de visualización de la señal, con clases específicas para cada tipo de gráfico (`GraficoTiempo`, `GraficoFrecuencia`), implementando una interfaz común.
5. **Interfaz de Usuario**:
    - Permite al usuario seleccionar modos de visualización, cambiar escalas y recibir notificaciones de estado de la conexión.
    - Las pantallas principales y widgets modulares facilitan la interacción y el cambio de configuraciones.

## Principios SOLID

Se aplican principios **SOLID** para mejorar la modularidad y flexibilidad de la aplicación:
- **Responsabilidad Única (SRP)**: Cada clase tiene una única responsabilidad, como el procesamiento de datos o la adquisición de señales.
- **Abierto/Cerrado (OCP)**: Las clases están diseñadas para ser extendibles sin necesidad de modificar su código.
- **Sustitución de Liskov (LSP)**: Las clases derivadas, como `OsciloscopioWifi`, pueden usarse sin alterar el comportamiento general de la app.
- **Segregación de Interfaces (ISP)**: Las interfaces se dividen según las necesidades, evitando que las clases implementen métodos que no usan.
- **Inversión de Dependencias (DIP)**: Las clases dependen de abstracciones, permitiendo cambiar la implementación (e.g., `SocketService`) sin afectar otras capas.

## Robustez y Manejo de Conexiones

Para asegurar una experiencia de usuario confiable:
- **Intentos de Reconexión**: `SocketService` incluye lógica de reconexión y alertas para el usuario.
- **Alertas Informativas**: La aplicación notifica al usuario si la conexión Wi-Fi es inestable o si hay demoras en el procesamiento de datos.
- **Logs y Depuración**: Los servicios de procesamiento y comunicación incluyen logs para facilitar el diagnóstico de problemas de comunicación y rendimiento en tiempo real.

## Estructura de Carpetas

```bash
├── lib
│   ├── config
│   │   ├── app_theme.dart
│   │   └── [initializer.dart](http://_vscodecontentref_/1)
│   ├── features
│   │   ├── http
│   │   │   └── domain
│   │   │       ├── models
│   │   │       │   └── http_config.dart
│   │   │       ├── repository
│   │   │       │   └── [http_repository.dart](http://_vscodecontentref_/2)
│   │   │       └── services
│   │   │           └── http_service.dart
│   │   ├── setup
│   │   │   ├── domain
│   │   │   │   ├── models
│   │   │   │   │   └── wifi_credentials.dart
│   │   │   │   ├── repository
│   │   │   │   │   └── [setup_repository.dart](http://_vscodecontentref_/3)
│   │   │   │   └── services
│   │   │   │       └── [setup_service.dart](http://_vscodecontentref_/4)
│   │   │   ├── providers
│   │   │   │   └── setup_provider.dart
│   │   │   ├── screens
│   │   │   │   └── setup_screen.dart
│   │   │   └── widgets
│   │   │       ├── [ap_selection_dialog.dart](http://_vscodecontentref_/5)
│   │   │       └── [show_wifi_network_dialog.dart](http://_vscodecontentref_/6)
│   │   └── socket
│   │       └── domain
│   │           ├── models
│   │           │   └── socket_connection.dart
│   │           ├── repository
│   │           │   └── [socket_repository.dart](http://_vscodecontentref_/7)
│   │           └── services
│   │               └── socket_service.dart
│   └── [main.dart](http://_vscodecontentref_/8)