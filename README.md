# arg_osci_app

## Descripción General

Esta aplicación de osciloscopio, desarrollada en **Flutter**, se comunica con un dispositivo **ESP32** mediante **Wi-Fi**. Permite la adquisición, visualización y análisis de datos en tiempo real, ofreciendo funcionalidades de procesamiento de señales y análisis espectral.

## Requerimientos de producto

- REQ 1: Interfaz de comunicación inalámbrica
- REQ 2: Funcionalidades básicas de un osciloscopio
- REQ 3: Reproducible a bajo costo
- REQ 4: Código y hardware abierto
- REQ 5: Adaptable a otras tecnologías
- REQ 6: Mantenible a largo plazo

## Requerimientos APP

### Requerimientos funcionales

- REQFAPP1: Comunicación de control por Wi-Fi (REQ1)
- REQFAPP2: Comunicación de datos por Wi-Fi (REQ1)
- REQFAPP3: Configuración inicial por Wi-Fi (REQ1)
- REQFAPP4: Gráficos con escalas variables (REQ2)
- REQFAPP5: Filtro digital configurable por el usuario (REQ2)
- REQFAPP6: Trigger digital (REQ2)
- REQFAPP7: Soporte para múltiples dispositivos/entradas (REQ2 - REQ5)
- REQFAPP8: Multiplataforma (REQ3-REQ5)
- REQFAPP9: Tecnologías de código abierto (REQ4)

### Requerimientos no funcionales

- REQNFAPP1: Interfaz similar a un osciloscopio de mercado (REQ2)
- REQNFAPP2: Aplicar principios SOLID (REQ5 - REQ6)

### Funcionalidad Principal

La aplicación implementa un sistema completo de adquisición y análisis de señales, que incluye:

- **Comunicación Wi-Fi**: Soporte para configuración inicial y transmisión de datos en tiempo real mediante sockets y HTTP.
- **Sistema de Trigger Digital**: Con detección de flancos y control de histéresis configurable.
- **Procesamiento Avanzado**: Incluye FFT en tiempo real, filtros configurables (Media Móvil, Exponencial, Paso Bajo) y cálculo de métricas (frecuencia, valores máximos/mínimos, promedio).
- **Visualización Interactiva**: Permite análisis en dominios de tiempo y frecuencia, con zoom multitáctil, desplazamiento y autoajuste de escalas.
- **Modos de Adquisición**: Modos Normal (adquisición continua) y Single (captura única al detectar trigger).
- **Sistema de Autoajuste**: Ajuste automático de escalas de tiempo y amplitud para optimizar la visualización.

### Sistemas operativos soportados

La aplicación es compatible con Android, Linux y Windows.

### Flujo de Funcionamiento

1. **Inicialización del Sistema**:
   - Configuración de orientación landscape forzada.
   - Gestión de permisos de ubicación para Wi-Fi.
   - Establecimiento del entorno de ejecución.

2. **Configuración de Red**:
   - Conexión inicial al AP del ESP32.
   - Selección de modo de operación (AP Local o AP Externo).
   - Encriptación RSA para credenciales (en modo AP Externo).

3. **Adquisición y Procesamiento**:
   - Muestreo a 1.65MHz con resolución de 16 bits.
   - Sistema de buffering circular para datos en tiempo real.
   - Procesamiento mediante isolates dedicados para no bloquear el hilo principal.
   - Escalas de voltaje configurables.
   - Pipeline de filtrado configurable.

4. **Visualización de Datos**:
   - Modo temporal con trigger configurable.
   - Análisis espectral mediante FFT optimizada.
   - Sistema de zoom y desplazamiento multitáctil.
   - Autoajuste de escalas y visualización.

### Componentes Principales

1. **Sistema de Comunicación**:
    - Implementación dual Socket/HTTP para control y datos.
    - Gestión de conexión y reconexión robusta.
    - Encriptación para datos sensibles.
    - Monitoreo continuo del estado de la conexión.
    - Uso de `HttpService` y `SocketService` para la comunicación.

2. **Procesamiento de Señales**:
    - Pipeline de filtrado configurable (Media Móvil, Exponencial, Paso Bajo).
    - Sistema de trigger con histéresis y detección de flancos.
    - Análisis espectral mediante FFT optimizada.
    - Cálculo en tiempo real de métricas de señal (frecuencia, valores máximos/mínimos, promedio).
    - Uso de Isolates para procesamiento en paralelo.

3. **Sistema de Visualización**:
    - Visualización temporal con trigger sincronizado.
    - Análisis espectral con detección de frecuencia.
    - Sistema de zoom y navegación multitáctil.
    - Autoajuste dinámico de escalas.
    - Uso de `OscilloscopeChartService` y `FFTChartService` para la visualización.

4. **Gestión de Estado**:
    - Arquitectura reactiva basada en GetX.
    - Variables observables para parámetros críticos.
    - Control granular de actualizaciones.
    - Gestión eficiente de recursos.
    - Uso de Providers (e.g., `DataAcquisitionProvider`, `UserSettingsProvider`) para la gestión del estado.

## Estructura de Carpetas

```bash
├── config
│   ├── app_theme.dart
│   └── initializer.dart
├── features
│   ├── graph
│   │   ├── domain
│   │   │   ├── models
│   │   │   │   ├── data_point.dart
│   │   │   │   ├── device_config.dart
│   │   │   │   ├── filter_types.dart
│   │   │   │   ├── graph_mode.dart
│   │   │   │   ├── trigger_data.dart
│   │   │   │   ├── unit_format.dart
│   │   │   │   └── voltage_scale.dart
│   │   │   ├── repository
│   │   │   │   ├── data_acquisition_repository.dart
│   │   │   │   ├── fft_chart_repository.dart
│   │   │   │   └── oscilloscope_chart_repository.dart
│   │   │   └── services
│   │   │       ├── data_acquisition_service.dart
│   │   │       ├── fft_chart_service.dart
│   │   │       └── oscilloscope_chart_service.dart
│   │   ├── providers
│   │   │   ├── data_acquisition_provider.dart
│   │   │   ├── device_config_provider.dart
│   │   │   ├── fft_chart_provider.dart
│   │   │   ├── oscilloscope_chart_provider.dart
│   │   │   └── user_settings_provider.dart
│   │   ├── screens
│   │   │   ├── graph_screen.dart
│   │   │   └── mode_selection_screen.dart
│   │   └── widgets
│   │       ├── fft_chart.dart
│   │       ├── oscilloscope_chart.dart
│   │       └── user_settings.dart
│   ├── http
│   │   └── domain
│   │       ├── models
│   │       │   └── http_config.dart
│   │       ├── repository
│   │       │   └── http_repository.dart
│   │       └── services
│   │           └── http_service.dart
│   ├── setup
│   │   ├── domain
│   │   │   ├── models
│   │   │   │   ├── setup_status.dart
│   │   │   │   └── wifi_credentials.dart
│   │   │   ├── repository
│   │   │   │   └── setup_repository.dart
│   │   │   └── services
│   │   │       └── setup_service.dart
│   │   ├── providers
│   │   │   └── setup_provider.dart
│   │   ├── screens
│   │   │   └── setup_screen.dart
│   │   └── widgets
│   │       ├── ap_selection_dialog.dart
│   │       └── show_wifi_network_dialog.dart
│   └── socket
│       └── domain
│           ├── models
│           │   └── socket_connection.dart
│           ├── repository
│           │   └── socket_repository.dart
│           └── services
│               └── socket_service.dart
└── main.dart
```

Cada feature sigue una estructura organizada y detallada:

- **Domain**:
  - **Models**: Contiene todos los modelos de datos y funciones auxiliares para la conversión de JSON a Dart y viceversa. Estos modelos representan las entidades y estructuras de datos fundamentales que utiliza la aplicación.
  - **Repository**: Contiene clases abstractas que describen la funcionalidad de la feature. Estas clases definen los contratos que deben cumplir las implementaciones de los servicios, asegurando una separación clara entre la lógica de negocio y la implementación concreta.
  A la vez, incluyen la documentacion de lo que hace cada clase y sus metodos.
  - **Services**: Contiene la implementación real de los repositorios. Aquí es donde se lleva a cabo la lógica de negocio, las llamadas a APIs, la gestión de bases de datos y cualquier otra operación necesaria para cumplir con los contratos definidos en los repositorios.

- **Providers**: Contiene todo lo relacionado con la gestión del estado para esa feature en particular. Esto incluye controladores, proveedores de estado y cualquier otra lógica necesaria para mantener y actualizar el estado de la aplicación de manera reactiva.

- **Screens**: Contiene pantallas completas que tienen un Scaffold. Estas pantallas representan vistas completas de la aplicación, incluyendo la disposición de widgets, la navegación y la interacción del usuario.

- **Widgets**: Contiene todos los widgets necesarios para esa feature en particular. Estos componentes reutilizables encapsulan partes de la interfaz de usuario, permitiendo una construcción modular y mantenible de las vistas.