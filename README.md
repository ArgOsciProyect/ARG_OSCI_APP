# arg_osci_app

## Descripción General

Este proyecto consiste en el desarrollo de una aplicación de osciloscopio, diseñada en **Flutter** y que se comunica con un dispositivo **ESP32** mediante **Wi-Fi**. La aplicación permite la adquisición y análisis de datos en tiempo real, ofreciendo capacidades avanzadas de visualización, procesamiento de señales y análisis espectral.

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

La aplicación implementa un sistema completo de adquisición y análisis de señales que incluye:
- **Comunicación Wi-Fi**: Soporta configuración inicial y transmisión de datos en tiempo real mediante sockets y HTTP
- **Sistema de Trigger Digital**: Con detección de flancos y control de histéresis
- **Procesamiento Avanzado**: Incluye FFT en tiempo real y múltiples opciones de filtrado
- **Visualización Interactiva**: Permite análisis en dominios de tiempo y frecuencia

### Sistemas operativos soportados

La aplicación funcionará en Android, Linux y Windows.

### Flujo de Funcionamiento

1. **Inicialización del Sistema**: 
   - Configuración de orientación landscape forzada
   - Gestión de permisos de ubicación para Wi-Fi
   - Establecimiento del entorno de ejecución

2. **Configuración de Red**: 
   - Conexión inicial al AP del ESP32
   - Selección de modo de operación (AP dedicado o red externa)
   - Sistema de encriptación RSA para credenciales

3. **Adquisición y Procesamiento**: 
   - Muestreo a 1.65MHz con resolución de 16 bits
   - Sistema de buffering circular para datos en tiempo real
   - Procesamiento mediante isolates dedicados
   - Múltiples escalas de voltaje configurables

4. **Visualización de Datos**: 
   - Modo temporal con trigger configurable
   - Análisis espectral mediante FFT optimizada
   - Sistema de zoom y desplazamiento multitáctil
   - Autoajuste de escalas y visualización

### Componentes Principales

1. **Sistema de Comunicación**:
    - Implementación dual Socket/HTTP para control y datos
    - Gestión robusta de reconexiones y errores
    - Sistema de encriptación para datos sensibles
    - Monitoreo continuo de estado de conexión

2. **Procesamiento de Señales**:
    - Pipeline de filtrado configurable (Kalman, Media Móvil, Paso Bajo)
    - Sistema de trigger con histéresis y detección de flancos
    - Análisis espectral mediante FFT optimizada
    - Cálculo en tiempo real de métricas de señal

3. **Sistema de Visualización**:
    - Visualización temporal con trigger sincronizado
    - Análisis espectral con detección de frecuencia
    - Sistema de zoom y navegación multitáctil
    - Autoajuste dinámico de escalas

4. **Gestión de Estado**:
    - Arquitectura reactiva basada en GetX
    - Sistema de observables para parámetros críticos
    - Control granular de actualizaciones
    - Gestión eficiente de recursos

## Principios SOLID

La aplicación implementa rigurosamente los principios SOLID:
- **Single Responsibility**: Separación clara de responsabilidades en servicios especializados
- **Open/Closed**: Arquitectura extensible mediante interfaces abstractas
- **Liskov Substitution**: Jerarquía coherente de servicios y providers
- **Interface Segregation**: APIs mínimas y específicas por componente
- **Dependency Inversion**: Inyección de dependencias para desacoplamiento

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
│   │   │   │   └── voltage_scale.dart
│   │   │   ├── repository
│   │   │   │   ├── data_acquisition_repository.dart
│   │   │   │   ├── fft_chart_repository.dart
│   │   │   │   └── line_chart_repository.dart
│   │   │   └── services
│   │   │       ├── data_acquisition_service.dart
│   │   │       ├── fft_chart_service.dart
│   │   │       └── line_chart_service.dart
│   │   ├── providers
│   │   │   ├── data_provider.dart
│   │   │   ├── device_config_provider.dart
│   │   │   ├── fft_chart_provider.dart
│   │   │   ├── graph_mode_provider.dart
│   │   │   └── line_chart_provider.dart
│   │   ├── screens
│   │   │   ├── graph_screen.dart
│   │   │   └── mode_selection_screen.dart
│   │   └── widgets
│   │       ├── fft_chart.dart
│   │       ├── line_chart.dart
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

Cada feature sigue una estructura organizada:
- **Domain**: Modelos, repositorios e interfaces de servicio
- **Providers**: Gestión de estado específica por feature
- **Screens**: Interfaces de usuario completas
- **Widgets**: Componentes reutilizables