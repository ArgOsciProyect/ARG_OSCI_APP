# Flujo del Programa

## Conexión a la Red Local AP
1. `connectToLocalAP()`: Espera a que el usuario esté conectado a la red ESP32 (verificándolo con `networkInfo`).
2. Cuando el usuario está conectado, crea una instancia de `HttpService` con la IP "192.168.4.1".

## Selección del Modo de Operación
1. Hace un POST a la ESP32 con el modo seleccionado (External AP o Internal AP).
2. La ESP32 responderá:
    - **Modo External AP**: Devuelve una lista con todos los WiFis detectados por la ESP32.
    - **Modo Internal AP**: Devuelve la IP y el Puerto del socket.
        - Se setean las configuraciones globales `globalSocketConnection` (usando la IP y puerto recibidos) y `globalHttpConfig` (usando la IP recibida).

## Modo External AP
1. El usuario selecciona el WiFi recibido y escribe su contraseña (como se ve en `show_wifi_network_dialog`).
2. Una vez tenemos el SSID y la contraseña de la red a utilizar, se la posteamos a la ESP32.
3. La ESP32 se conectará a esta red y nos responderá con una IP y un puerto.
4. Indicamos al usuario que se cambie de red WiFi a la seleccionada anteriormente y esperamos a que ocurra esto (usamos `networkInfo`).
5. Una vez cambiado de red:
    - Se setean las configuraciones globales `globalSocketConnection` (usando la IP y puerto recibidos) y `globalHttpConfig` (usando la IP recibida).

## Configuración Inicial
1. `Initializer.init()`: Inicializa las configuraciones globales y registra los servicios y proveedores necesarios.
2. Se crean instancias de `HttpConfig` y `SocketConnection` con valores predeterminados.
3. Se registran las configuraciones globales en el contenedor de dependencias (`Get`).
4. Se inicializan y registran los servicios de adquisición de datos, configuración y gráficos.
5. Se inicializan y registran los proveedores de configuración y gráficos.

## Adquisición de Datos
1. `fetchData(String ip, int port)`: Inicia la adquisición de datos desde el ESP32.
2. Se crean y configuran los isolates para el procesamiento de datos y la conexión del socket.
3. Los datos recibidos se procesan en el isolate de procesamiento y se envían al isolate principal.
4. Los datos procesados se añaden al stream de datos para su visualización.
5. Se aplican filtros y escalas a los datos adquiridos:
    - **Filtros**: Se pueden aplicar filtros como el filtro de media móvil o el filtro de Kalman para suavizar los datos.
    - **Escalas**: Se ajustan las escalas de tiempo y valor para una visualización adecuada.

## Procesamiento de Datos FFT
1. `FFTChartService`: Escucha el stream de datos y acumula los puntos de datos.
2. Cuando se acumulan suficientes puntos de datos (definidos por `blockSize`), se envían al isolate de procesamiento FFT.
3. El isolate de procesamiento FFT calcula la FFT y devuelve los resultados al isolate principal.
4. Los resultados de la FFT se añaden al stream de FFT para su visualización.

## Visualización de Datos
1. `LineChartService`: Escucha su propio stream de datos al que se le podria aplicar un procesamiento particular en un futuro y los envía al controlador de datos para su visualización en tiempo real.
2. `FFTChartService`: Escucha el stream de FFT y los envía al controlador de FFT para su visualización en tiempo real.

## Manejo de Conexiones y Configuraciones
1. `SetupService`: Maneja la conexión a la red WiFi y la configuración de los servicios de socket y HTTP.
2. `connectToLocalAP()`: Espera a que el usuario se conecte a la red ESP32 y configura `HttpService`.
3. `selectMode(String mode)`: Envía el modo seleccionado a la ESP32 y maneja la respuesta.
4. `connectToExternalAP(String ssid, String password)`: Envía las credenciales de la red WiFi a la ESP32 y maneja la respuesta.
5. `waitForNetworkChange(String ssid)`: Espera a que el usuario se conecte a la red WiFi seleccionada.

## Proveedores de Datos y Gráficos
1. `GraphProvider`: Proporciona datos de adquisición y configuración a los servicios de gráficos.
2. `LineChartProvider`: Proporciona datos de gráficos de línea a `LineChartService`.
3. `FFTChartProvider`: Proporciona datos de gráficos FFT a `FFTChartService`.

## Servicios de Gráficos
1. `LineChartService`: Escucha su propio stream de datos y los envía al controlador de datos para su visualización en tiempo real.
2. `FFTChartService`: Escucha el stream de FFT y los envía al controlador de FFT para su visualización en tiempo real.
3. Ambos servicios manejan la suscripción a los datos y la limpieza de recursos cuando se cierran.

## Flujo Completo del Programa
1. El usuario se conecta a la red ESP32 y selecciona el modo de operación.
2. Dependiendo del modo seleccionado, se configuran las conexiones globales y se manejan las credenciales de la red WiFi.
3. Se inician los servicios de adquisición de datos y procesamiento de gráficos.
4. Los datos adquiridos se procesan y se envían a los servicios de gráficos para su visualización en tiempo real.
5. Los servicios de gráficos manejan la suscripción a los datos y la limpieza de recursos cuando se cierran.