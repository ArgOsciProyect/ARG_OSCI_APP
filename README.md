# arg_osci_app

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
- REQFAPP3: Comunicacion de emparejamiento inicial por BLE (REQ1)
- REQFAPP4: Graficador con escalas variables (REQ2)
- REQFAPP5: Opcion de filtro digital configurable por el usuario (REQ2)
- REQFAPP6: Trigger digital (REQ2)
- REQFAPP7: Tolerancia de mas de un dispositivo para multiples entradas (REQ2 - REQ5)
- REQFAPP8: Multiplataforma (REQ3-REQ5)
- REQFAPP9: Las tecnologias utilizadas deben ser de codigo abierto (REQ4)

### Requerimientos no funcionales
- REQNFAPP1: Interfaz similar a un osciloscopio de mercado (REQ2)
- REQNFAPP2: Aplicar principios SOLID (REQ5 - REQ6)

## Descripción General

Este proyecto consiste en el desarrollo de una aplicación de osciloscopio, diseñada en **Flutter** y que se comunica con un dispositivo **ESP32** mediante **Wi-Fi** y **Bluetooth**. La aplicación permite la adquisición de datos en tiempo real con capacidades de visualización y análisis, y permite al usuario seleccionar modos de funcionamiento, ajustar configuraciones de gráficos y recibir alertas de conexión.

### Funcionalidad Principal

La aplicación permite la interacción con el dispositivo ESP32 de las siguientes maneras:

- **Bluetooth**: Para configuración inicial, ajuste de modos y recepción de datos específicos (como la escala de voltaje).
- **Wi-Fi**: Para recibir datos de adquisición de señales en tiempo real.

### Flujo de Funcionamiento

1. **Conexión Bluetooth**: La aplicación inicia una conexión Bluetooth con el ESP32 y realiza un intercambio de claves mediante **RSA** para establecer la clave de cifrado **AES**, que será utilizada en la comunicación posterior.
2. **Configuración de Red Wi-Fi**: El usuario elige si el ESP32 funcionará en modo **AP (Access Point)** (opción recomendada, pero que implica la pérdida de acceso a internet) o si usará una red AP existente (más inestable). Las credenciales de red se encriptan con AES antes de ser enviadas.
3. **Adquisición y Procesamiento de Datos**: Una vez establecida la conexión Wi-Fi, el usuario accede al menú principal, donde puede seleccionar modos como "Osciloscopio" o "Analizador de Espectro". Los datos adquiridos vía Wi-Fi son procesados en la app, lo que puede incluir formato, compresión o transformaciones FFT para visualización en frecuencia.
4. **Visualización de Datos**: La aplicación ofrece varios modos de visualización, incluyendo:
    - **Gráfico en Tiempo**: Para visualizar la señal en el dominio temporal.
    - **Gráfico en Frecuencia**: Para visualizar la señal en el dominio de la frecuencia (requiere cálculo de FFT).
    - **Otros Modos Específicos**: Por ejemplo, visualización de una curva de capacitor, entre otros.

5. **Interacción del Usuario**: El usuario puede ajustar parámetros de gráficos (como escala y modo de visualización) y recibir alertas sobre la estabilidad de la conexión Wi-Fi o sobre demoras en el procesamiento.

## Arquitectura

Para asegurar modularidad, mantenibilidad y escalabilidad, la aplicación sigue los principios de **Clean Architecture** y **Domain-Driven Design (DDD)**. La estructura del código está dividida en capas, cada una con responsabilidades específicas:

- **Domain**: Define los conceptos del dominio, incluyendo las entidades (`DispositivoOsciloscopio`, `DatosAdquisicion`, etc.) y los casos de uso (`ConectarBluetooth`, `EstablecerConexionWiFi`, `ObtenerDatosAdquisicion`, `CambiarModoGraficador`).
- **Application**: Maneja la lógica de estado de la app y contiene servicios para tareas específicas de la aplicación (e.g., `BluetoothService`, `WiFiService`, `DataProcessingService`), permitiendo la comunicación con el hardware y el procesamiento de datos.
- **Data**: Gestiona los repositorios y fuentes de datos, como el acceso a los dispositivos (Wi-Fi y Bluetooth) y el manejo de datos encriptados. Define modelos para mapear los datos provenientes de la ESP32.
- **Presentation**: Contiene las pantallas y widgets para la interfaz de usuario, organizados de manera modular para facilitar la interacción del usuario y la visualización de los datos.

### Estructura de Carpetas

La estructura de carpetas se organiza de la siguiente forma para mantener el código modular y escalable:

``` bash
lib/
├── domain/
│   ├── entities/
│   └── use_cases/
├── application/
│   ├── bloc/ (o controllers/)
│   └── services/
├── data/
│   ├── models/
│   ├── repositories/
│   └── datasources/
└── presentation/
├── screens/
├── widgets/
└── utils/
```

## Componentes Principales

1. **Control/Comunicación (Bluetooth)**:
    - Gestiona la configuración y el cambio de modos del dispositivo desde la app.
    - Permite recibir ajustes específicos (como escala de voltaje) desde el dispositivo.
    - Implementación en `BluetoothService`, que también maneja el intercambio de claves RSA y el cifrado AES.

2. **Adquisición de Datos (Wi-Fi)**:
    - Responsable de recibir datos en tiempo real desde el ESP32 en modo AP o red externa.
    - La comunicación de credenciales y datos se maneja de forma segura mediante cifrado AES.
    - Se implementa en `WiFiService` y `DatosRepository`, que facilitan la conexión y mantienen la estabilidad de la misma.

3. **Procesamiento de Datos**:
    - Da formato a los datos recibidos y aplica transformaciones como compresión o cálculo de FFT.
    - `DataProcessingService` se encarga de este procesamiento, permitiendo que los datos estén listos para su visualización en la interfaz de usuario.

4. **Visualización de Datos**:
    - Ofrece varios modos de visualización de la señal, con clases específicas para cada tipo de gráfico (`GraficoTiempo`, `GraficoFrecuencia`), implementando una interfaz común.
    - Permite cambiar entre modos de visualización según la elección del usuario, asegurando flexibilidad en la representación de los datos.

5. **Interfaz de Usuario**:
    - Permite al usuario seleccionar modos de visualización, cambiar escalas y recibir notificaciones de estado de la conexión.
    - Las pantallas principales y widgets modulares facilitan la interacción y el cambio de configuraciones.

## Principios SOLID

Se aplican principios **SOLID** para mejorar la modularidad y flexibilidad de la aplicación:

- **Responsabilidad Única (SRP)**: Cada clase tiene una única responsabilidad, como el procesamiento de datos o la adquisición de señales.
- **Abierto/Cerrado (OCP)**: Las clases están diseñadas para ser extendibles sin necesidad de modificar su código.
- **Sustitución de Liskov (LSP)**: Las clases derivadas, como `OsciloscopioWifi` y `OsciloscopioBluetooth`, pueden usarse sin alterar el comportamiento general de la app.
- **Segregación de Interfaces (ISP)**: Las interfaces se dividen según las necesidades, evitando que las clases implementen métodos que no usan.
- **Inversión de Dependencias (DIP)**: Las clases dependen de abstracciones, permitiendo cambiar la implementación (e.g., `BluetoothService`) sin afectar otras capas.

## Robustez y Manejo de Conexiones

Para asegurar una experiencia de usuario confiable:
- **Intentos de Reconexión**: `WiFiService` y `BluetoothService` incluyen lógica de reconexión y alertas para el usuario.
- **Alertas Informativas**: La aplicación notifica al usuario si la conexión Wi-Fi es inestable o si hay demoras en el procesamiento de datos.
- **Logs y Depuración**: Los servicios de procesamiento y comunicación incluyen logs para facilitar el diagnóstico de problemas de comunicación y rendimiento en tiempo real.
