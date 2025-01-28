# Documentación Técnica - Osciloscopio AR

## Índice
1. Marco Teórico y Conceptos Fundamentales
2. Arquitectura del Sistema
3. Sistema de Inicialización y Configuración
4. Sistema de Adquisición y Procesamiento de Datos
5. Sistema de Visualización
6. Sistemas de Comunicación
7. Gestión de Estados y Eventos

# 1. Marco Teórico y Conceptos Fundamentales

## Temas para Marco Teórico:
1. GetX - Framework de gestión de estados y navegación
2. Sistemas de permisos en Android
3. Orientación de pantalla en dispositivos móviles
4. Arquitectura de navegación en aplicaciones Flutter
5. RSA Encryption y Criptografía Asimétrica
6. Redes WiFi y Access Points (AP)
7. Protocolos de comunicación Socket y HTTP
8. ESP32 como Access Point
9. Arquitectura de servicios en Flutter/Dart
10. Patrón Repository
11. Gestión de estados con GetX - Observables
12. Transformada Rápida de Fourier (FFT)
13. Servicio de adquisición de datos en tiempo real
14. Visualización de datos mediante gráficos LineChart
15. Dependency Injection en Flutter
16. Gestión de configuración en aplicaciones móviles
17. Sistemas de buffering y gestión de memoria en tiempo real
18. Filtros digitales (Kalman, Moving Average, Low Pass)
19. Sistemas de interacción táctil y gestión de gestos
20. WebSockets y comunicación bidireccional
21. Patrones Observer y Factory en Flutter
22. Sistemas de procesamiento en tiempo real con Isolates

# 2. Sistema de Inicialización y Configuración Base

## 2.1 Proceso de Inicialización

### 2.1.1 Configuración Base del Sistema
El proceso de inicialización del sistema establece las condiciones fundamentales para la ejecución de la aplicación:

1. **Preparación del Framework**
   - Inicialización del binding de Flutter para garantizar la disponibilidad de servicios nativos
   - Configuración forzada de orientación landscape para optimizar la visualización de señales
   - Establecimiento del entorno de ejecución

2. **Gestión de Permisos**
   El sistema requiere permisos específicos para su funcionamiento en dispositivos Android:
   - Ubicación permanente: Necesario para operaciones WiFi en segundo plano
   - Detección de dispositivos WiFi cercanos: Esencial para la conexión con el hardware
   - Ubicación general: Requerido para funcionalidades de red

### 2.1.2 Estructura de Navegación
La aplicación implementa un sistema de navegación jerárquico mediante GetMaterialApp:

1. **Configuración General**
   - Identificador: 'ARG_OSCI'
   - Tema personalizado adaptado a la visualización de señales
   - Sistema de navegación basado en rutas nombradas

2. **Jerarquía de Navegación**
   - Pantalla inicial (SetupScreen): Configuración y conexión
   - Selección de modo (ModeSelectionScreen): Definición del tipo de análisis
   - Visualización (GraphScreen): Presentación y análisis de señales

## 2.2 Sistema de Inicialización Jerárquica

### 2.2.1 Gestión de Dependencias
El sistema implementa una secuencia específica de inicialización para garantizar la disponibilidad de servicios:

1. **Configuración del Dispositivo**
   - Registro del DeviceConfigProvider como servicio permanente
   - Establecimiento de parámetros base de operación
   - Sistema de persistencia de configuración

2. **Servicios de Comunicación**
   - Configuración HTTP: Establecimiento de endpoint base (192.168.4.1:81)
   - Configuración Socket: Preparación de canal bidireccional (Puerto 8080)
   - Sistema de reconexión automática

3. **Sistema de Procesamiento**
   La inicialización establece una cadena de procesamiento de datos:
   - Servicio de adquisición vinculado al sistema de comunicación
   - Proveedor de datos para gestión de estado
   - Sistema de buffering para procesamiento en tiempo real

4. **Servicios de Visualización**
   Se establecen los sistemas de representación visual:
   - Servicio FFT para análisis espectral
   - Servicio de gráfico temporal
   - Sistema de control de modo de visualización

5. **Sistema de Configuración**
   - Inicialización del servicio de configuración
   - Establecimiento del proveedor de estados
   - Preparación de interfaces de usuario

# 3. Sistema de Configuración y Conexión

## 3.1 Establecimiento de Conexión

### 3.1.1 Gestión de Credenciales WiFi
La conexión con el dispositivo requiere un sistema robusto de gestión de credenciales:

1. **Modelo de Credenciales**
   - Estructura de datos para credenciales WiFi
   - Sistema de serialización JSON bidireccional
   - Encriptación de datos sensibles
   - Validación de formato de credenciales

2. **Procesamiento de Credenciales**
   - Encriptación RSA de contraseñas
   - Verificación de integridad de datos
   - Gestión de errores de formato
   - Sistema de respaldo de configuración

### 3.1.2 Control de Red
El sistema implementa múltiples capas de control para garantizar una conexión estable:

1. **Monitoreo de Estado**
   - Verificación continua de conectividad
   - Detección de cambios de red
   - Sistema de reconexión automática
   - Registro de eventos de red

2. **Gestión de Access Points**
   - Control de acceso al AP local
   - Validación de identidad del dispositivo
   - Monitoreo de potencia de señal
   - Sistema de fallback automático

## 3.2 Servicios de Red

### 3.2.1 NetworkInfoService
Implementa las operaciones fundamentales de red:

1. **Sistema de Reintentos**
   - Máximo 5 intentos de conexión
   - Intervalos de reintento configurables
   - Gestión de timeouts
   - Notificación de estado de conexión

2. **Verificación de Conectividad**
   - Pruebas de endpoint periódicas
   - Sistema de heartbeat
   - Detección de latencia
   - Registro de métricas de red

### 3.2.2 SetupService
Coordina todas las operaciones de configuración:

1. **Gestión de Conexiones**
   - Control de sockets y HTTP
   - Manejo de estados de conexión
   - Sistema de verificación challenge-response
   - Coordinación de servicios de red

2. **Control de Seguridad**
   - Gestión de claves RSA
   - Verificación de identidad
   - Protección de datos sensibles
   - Auditoría de operaciones

## 3.3 Interfaz de Usuario

### 3.3.1 Pantalla de Configuración
La interfaz principal de configuración implementa:

1. **Componentes Visuales**
   - Barra de título personalizada
   - Botón principal de configuración
   - Indicadores de estado
   - Sistema de notificaciones

2. **Gestión de Estados**
   - Indicación de progreso
   - Estados de conexión
   - Mensajes de error
   - Retroalimentación visual

### 3.3.2 Diálogos del Sistema
El sistema implementa diálogos especializados:

1. **Selección de AP**
   - Indicador de progreso
   - Opciones de modo AP
   - Sistema de notificaciones
   - Gestión de errores

2. **Configuración de Red**
   - Lista de redes disponibles
   - Sistema de credenciales
   - Indicadores de estado
   - Control de proceso

## 3.4 Flujo de Configuración

### 3.4.1 Proceso de Inicialización
Secuencia de configuración inicial:

1. **Preparación del Sistema**
   - Carga de componentes
   - Verificación de permisos
   - Inicialización de servicios
   - Establecimiento de estados base

2. **Configuración de Red**
   - Activación de interfaces
   - Escaneo de redes
   - Establecimiento de conexión
   - Verificación de estado

### 3.4.2 Flujos de Operación
El sistema soporta dos flujos principales:

1. **Modo AP Local**
   - Conexión directa
   - Configuración interna
   - Verificación de estado
   - Transición a operación

2. **Modo AP Externo**
   - Selección de red
   - Proceso de credenciales
   - Verificación de conexión
   - Establecimiento de comunicación

# 4. Servicios de Comunicación

## 4.1 Sistema de Comunicación HTTP

### 4.1.1 Arquitectura y Componentes
El sistema de comunicación HTTP implementa una arquitectura en capas que garantiza la robustez y mantenibilidad:

1. **Configuración Base**
   - Encapsulamiento de URL base (192.168.4.1:81)
   - Gestión del ciclo de vida del cliente HTTP
   - Sistema de serialización para configuración
   - Mecanismos de reinicialización

2. **Capa de Abstracción**
   - Definición de operaciones HTTP fundamentales
   - Sistema unificado de gestión de errores
   - Tipado fuerte de respuestas
   - Manejo estandarizado de endpoints

3. **Implementación del Servicio**
   - Sistema robusto de manejo de errores
   - Procesamiento automático de JSON
   - Gestión de cabeceras HTTP
   - Control de estado de conexión

### 4.1.2 Operaciones del Sistema
El servicio HTTP proporciona dos operaciones fundamentales:

1. **Operaciones GET**
   - Construcción de URLs parametrizadas
   - Sistema de validación de respuestas
   - Decodificación automática de JSON
   - Manejo estructurado de errores

2. **Operaciones POST**
   - Serialización automática de cuerpos
   - Gestión de Content-Type
   - Sistema de reintentos configurable
   - Validación de respuestas del servidor

## 4.2 Sistema de Comunicación Socket

### 4.2.1 Estructura Principal
El sistema Socket implementa una arquitectura que garantiza la comunicación bidireccional en tiempo real:

1. **Gestión de Conexión**
   - Control reactivo de IP y puerto
   - Sistema observable con GetX
   - Persistencia de configuración
   - Actualización dinámica de parámetros

2. **Capa de Abstracción**
   - Operaciones Socket fundamentales
   - Gestión del ciclo de vida
   - Sistema de eventos y suscripciones
   - Control de flujo de datos

3. **Servicio de Implementación**
   - Gestión de conexiones TCP
   - Sistema de transmisión bidireccional
   - Control de múltiples suscriptores
   - Manejo robusto de desconexiones

### 4.2.2 Sistema de Transmisión de Datos

1. **Envío de Datos**
   - Codificación UTF-8 de mensajes
   - Sistema de terminación de mensajes
   - Gestión de buffer de transmisión
   - Control de errores de escritura

2. **Recepción de Datos**
   - Stream controller en modo broadcast
   - Decodificación UTF-8 de mensajes
   - Sistema de suscripciones múltiple
   - Gestión de cierre de conexiones

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

2. **Gestión de Recursos**
   - Control de buffer de transmisión
   - Sistema de backpressure
   - Gestión eficiente de memoria
   - Limpieza automática de recursos

# 5. Sistema de Visualización y Procesamiento

## 5.1 Configuración y Adquisición de Datos

### 5.1.1 Configuración del Hardware
1. **Parámetros Base**
   - Obtención mediante endpoint /config durante la inicialización
   - Almacenamiento en DeviceConfigProvider:
     * Frecuencia de muestreo: 1.65MHz
     * Bits por paquete: 16 bits
     * Máscara de datos: 0x0FFF
     * Máscara de canal: 0xF000
     * Bits efectivos: 9
     * Muestras por paquete: 8192

2. **Sistema de Escalado**
   - Factores de escala predefinidos (VoltageScale):
     * Rango Alto: ±400V (factor 800/512)
     * Rango Medio: ±2V, ±1V (factores 4.0/512, 2.0/512)
     * Rango Bajo: ±500mV, ±200mV, ±100mV (factores 1/512, 0.4/512, 0.2/512)
   - Actualización dinámica de configuración en DataAcquisitionService
   - Propagación de cambios al sistema de visualización

## 5.2 Preprocesamiento y Gestión de Datos

### 5.2.1 Arquitectura de Procesamiento
1. **Sistema de Isolates**
   - Isolate de Socket dedicado para comunicación UDP
   - Isolate de Procesamiento para análisis en tiempo real
   - Comunicación mediante SendPorts y StreamController
   - Sistema de cleanup y gestión de recursos

2. **Pipeline de Datos**
   - Buffer circular con capacidad 6x el tamaño del chunk
   - Chunks de procesamiento de 8192 muestras
   - Decodificación de paquetes de 16 bits en little-endian
   - Separación de datos (0x0FFF) y canal mediante máscaras

### 5.2.2 Sistema de Trigger
1. **Modos de Operación**
   - Histéresis con sensibilidad configurable
     * Control de rebotes (sensibilidad: 70.0)
     * Bandas de histéresis dinámicas según escala
   - Filtro Paso Bajo
     * Pre-filtrado a 50kHz
     * Coeficientes adaptativos según frecuencia de muestreo
   - Detección configurable de flancos
     * Positivo (rising edge)
     * Negativo (falling edge)

2. **Procesamiento de Trigger**
   - Buffer circular para detección continua
   - Sistema de ventana post-trigger
   - Normalización de puntos según trigger
   - Cálculo de métricas por ventana

### 5.2.3 Sistema de Filtrado
1. **Tipos de Filtros**
   - Kalman con parámetros optimizados
     * Error de medición: 256
     * Error estimado: 150
     * Factor Q: 0.9
   - Media móvil con ventana configurable
   - Filtro exponencial (alpha: 0.2)
   - Paso bajo con frecuencia de corte variable

2. **Gestión de Filtrado**
   - Aplicación en tiempo real
   - Parámetros configurables dinámicamente
   - Sistema reactivo de actualización
   - Optimización de recursos

### 5.2.4 Sistema de Escalado
1. **Escalas de Voltaje**
   - Rangos predefinidos:
     * Alto: ±400V (factor 800/512)
     * Medio: ±2V, ±1V (factores 4.0/512, 2.0/512)
     * Bajo: ±500mV, ±200mV, ±100mV
   - Ajuste dinámico de trigger
   - Propagación de cambios al sistema

2. **Control de Escalas**
   - Escala temporal según frecuencia
   - Escala de valores según rango
   - Sistema de autoajuste
   - Normalización de coordenadas

### 5.2.5 Métricas y Autoajuste
1. **Cálculo de Métricas**
   - Frecuencia mediante intervalos entre triggers
   - Valores máximos y mínimos por ventana
   - Promedio móvil de señal
   - Actualización continua mediante streams

2. **Sistema de Autoajuste**
   - Ajuste temporal:
     * Visualización de 3 períodos
     * Adaptación según ancho de pantalla
   - Ajuste de amplitud:
     * Normalización según valor máximo
     * Centrado de trigger
     * Limitación según rango de voltaje

### 5.2.6 Sistema de Estado
1. **Gestión Reactiva**
   - Variables observables para parámetros críticos
   - Sistema de suscripción a streams
   - Propagación de cambios
   - Control mediante GetX

2. **Control de Flujo**
   - Sistema de pausa/reanudación
   - Gestión de recursos
   - Cleanup automático
   - Manejo de errores robusto

## 5.3 Visualización Temporal

### 5.3.1 Arquitectura de Visualización
1. **Modelo de Datos**
   - Flujo de puntos de datos mediante Stream broadcast
   - Sistema de pausa/reanudación de visualización
   - Control de distancia entre muestras
   - Gestión de recursos y memoria

2. **Sistema de Transformación**
   - Conversión entre dominios tiempo-pantalla
   - Cálculo dinámico de distancia entre muestras
   - Ajuste según frecuencia de muestreo
   - Sistema de coordenadas adaptativo

### 5.3.2 Gestión de Estado (LineChartProvider)
1. **Control de Vista**
   - Sistema de escalas independientes:
     * Escala temporal con factor base 1.0
     * Escala de valores con factor base 1.0
   - Offsets bidimensionales:
     * Desplazamiento horizontal para tiempo
     * Desplazamiento vertical para amplitud
   - Sistema de zoom con punto focal

2. **Interacción de Usuario**
   - Control mediante gestos:
     * Zoom multitáctil con preservación de punto focal
     * Arrastre para desplazamiento
     * Doble tap para reset
   - Control mediante periféricos:
     * Rueda de mouse para zoom
     * Teclado para navegación fina
     * Modificadores para control específico de ejes

### 5.3.3 Procesamiento de Datos
1. **Sistema de Streaming**
   - Suscripción al flujo de datos principal
   - Transformación de puntos según configuración
   - Control de estado de pausa
   - Gestión de recursos del sistema

2. **Control de Flujo**
   - Sistema de pausa/reanudación
   - Cancelación segura de suscripciones
   - Limpieza automática de recursos
   - Manejo de ciclo de vida

### 5.3.4 Optimización de Rendimiento
1. **Gestión de Memoria**
   - Sistema de buffering eficiente
   - Limpieza proactiva de recursos
   - Control de suscripciones
   - Manejo de ciclo de vida

2. **Renderizado Eficiente**
   - Sistema de coordenadas optimizado
   - Transformación selectiva de puntos
   - Actualización parcial de vista
   - Control de recursos gráficos

## 5.4 Análisis Espectral

### 5.4.1 Procesamiento FFT
1. **Adquisición de Datos**
   - Buffer dinámico de puntos de entrada
   - Tamaño de bloque configurable (8192 * 2 muestras)
   - Sistema de pausa/reanudación
   - Control de sobrecarga de procesamiento

2. **Algoritmo FFT**
   - Implementación optimizada con SIMD
   - Permutación de bits para ordenamiento
   - Procesamiento en bloques de 4 elementos
   - Cálculo de magnitudes y fases
   - Normalización automática de resultados

3. **Post-procesamiento**
   - Conversión a decibeles (dB)
   - Resolución frecuencial dinámica
   - Límite en frecuencia de Nyquist
   - Sistema de detección de picos

### 5.4.2 Detección de Frecuencia
1. **Análisis de Picos**
   - Umbral mínimo de -160 dB
   - Detección de pendiente positiva
   - Búsqueda de máximos locales
   - Validación de magnitudes

2. **Cálculo de Frecuencia**
   - Resolución basada en frecuencia de muestreo
   - Sistema de ventana deslizante
   - Filtrado de señales espurias
   - Actualización en tiempo real

### 5.4.3 Control de Visualización
1. **Gestión de Estado**
   - Sistema reactivo de puntos FFT
   - Control de escalas bidimensional
   - Sistema de pausa/reproducción
   - Actualización automática de frecuencia

2. **Sistema de Zoom**
   - Zoom multitáctil con factor cuadrático
   - Preservación de punto focal
   - Escalas independientes por eje
   - Sistema de límites dinámicos

3. **Control de Vista**
   - Desplazamiento bidimensional
   - Sistema de incremento/decremento fino
   - Autoajuste según frecuencia máxima
   - Gestión de timers de actualización

### 5.4.3 Optimización y Rendimiento
1. **Gestión de Recursos**
   - Control de memoria mediante buffering
   - Limpieza automática de datos
   - Sistema de pausa en segundo plano
   - Cancelación segura de suscripciones

2. **Control de Flujo**
   - Sistema de bloqueo durante procesamiento
   - Gestión de sobrecarga de datos
   - Control de estado de pausa
   - Manejo de errores robusto

3. **Renderizado Eficiente**
   - Actualización selectiva de vista
   - Sistema de doble buffer
   - Control de resolución adaptativo
   - Optimización de recursos gráficos

## 5.5 Sistema de Adquisición y Procesamiento

### 5.5.1 Arquitectura de Procesamiento
1. **Sistema de Isolates**
   - Isolate de Socket dedicado para comunicación de red
   - Isolate de Procesamiento para análisis en tiempo real
   - Comunicación mediante SendPorts y StreamController
   - Sistema de cleanup y gestión de recursos mediante ReceivePort

2. **Pipeline de Datos**
   - Buffer circular con capacidad 6x el tamaño del chunk
   - Chunks de procesamiento de 8192 muestras
   - Sistema de trigger en tiempo real
   - Métricas continuas: frecuencia, valores máx/mín, promedio

### 5.5.2 Procesamiento de Señales
1. **Decodificación de Datos**
   - Lectura de paquetes de 16 bits en little-endian
   - Extracción de datos mediante máscara 0x0FFF
   - Separación de canal mediante shift dinámico
   - Conversión a coordenadas normalizadas

2. **Sistema de Trigger**
   - Dos modos de operación:
     * Histéresis: Control de rebotes con sensibilidad 70.0
     * Filtro Paso Bajo: Pre-filtrado a 50kHz
   - Detección de flancos con buffer circular
   - Ventana temporal configurable post-trigger

### 5.5.3 Control de Flujo
1. **Gestión de Estado**
   - Control reactivo mediante GetX
   - Variables observables para parámetros críticos:
     * Nivel de trigger
     * Escalas de tiempo/valor
     * Modo de filtrado
     * Estado de adquisición
   - Sistema de pausa/reanudación

2. **Procesamiento de Datos**
   - Pipeline de filtrado configurable:
     * Kalman (errorMeasure: 256, errorEstimate: 150)
     * Media móvil con ventana ajustable
     * Filtro exponencial (alpha: 0.2)
     * Paso bajo con frecuencia de corte variable
   - Actualización en tiempo real de parámetros

### 5.5.4 Gestión de Recursos
1. **Control de Memoria**
   - Sistema de buffering circular eficiente
   - Límites dinámicos para cola de datos
   - Cleanup automático de datos antiguos
   - Gestión de suscripciones y streams

2. **Manejo de Errores**
   - Sistema de timeouts configurables
   - Reconexión automática con delay de 5 segundos
   - Cleanup seguro de isolates y recursos
   - Propagación estructurada de errores

### 5.5.5 Métricas y Autoajuste
1. **Cálculo de Métricas**
   - Frecuencia mediante intervalos entre triggers
   - Valores máximos y mínimos de señal
   - Promedio móvil de señal
   - Actualización continua mediante streams

2. **Sistema de Autoajuste**
   - Cálculo automático de escalas temporales:
     * 3 períodos de señal en pantalla
     * Ajuste de timeScale según ancho
   - Optimización de escalas de amplitud:
     * Normalización según valor máximo
     * Ajuste de trigger al punto medio
     * Limitación según rango de voltaje
