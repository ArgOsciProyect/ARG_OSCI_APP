import matplotlib.pyplot as plt
import numpy as np

# Definición de los datos para cada dispositivo
# Cada medición incluye: valor medio (mean), mínimo (min), máximo (max) y desviación estándar (std)
data = {
    'PC AP Interno': [
        {'mean': 1.44, 'std': 0.11, 'min': 1.22, 'max': 1.66},
        {'mean': 1.42, 'std': 0.11, 'min': 1.00, 'max': 1.66},
        {'mean': 1.41, 'std': 0.15, 'min': 0.58, 'max': 1.70},
        {'mean': 1.41, 'std': 0.15, 'min': 0.58, 'max': 1.70},
        {'mean': 1.07, 'std': 0.27, 'min': 0.43, 'max': 1.44}
    ],
    'PC AP Externo': [
        {'mean': 0.51, 'std': 0.11, 'min': 0.08, 'max': 0.69},
        {'mean': 0.50, 'std': 0.11, 'min': 0.08, 'max': 0.66},
        {'mean': 0.51, 'std': 0.09, 'min': 0.28, 'max': 0.66}
    ],
    'Celular AP Interno': [
        {'mean': 0.45, 'std': 0.18, 'min': 0.12, 'max': 0.80},
        {'mean': 0.40, 'std': 0.20, 'min': 0.03, 'max': 0.81},
        {'mean': 0.43, 'std': 0.20, 'min': 0.03, 'max': 0.81},
        {'mean': 0.39, 'std': 0.21, 'min': 0.03, 'max': 0.81}
    ]
}

# Asignación de colores para cada medio de conexión
colors = {
    'PC AP Interno': 'blue',
    'PC AP Externo': 'green',
    'Celular AP Interno': 'red'
}

# Posiciones en el eje X para cada categoría
device_positions = {'PC AP Interno': 0, 'PC AP Externo': 1, 'Celular AP Interno': 2}

fig, ax = plt.subplots(figsize=(10, 6))

# Se recorre cada dispositivo para graficar sus mediciones con un pequeño "jitter" en X
for device, measurements in data.items():
    x_base = device_positions[device]
    for i, meas in enumerate(measurements):
        # Se añade una variación aleatoria pequeña para evitar la superposición completa de puntos
        jitter = np.random.uniform(-0.1, 0.1)
        x = x_base + jitter
        mean = meas['mean']
        # Se calculan los errores: diferencia entre el valor medio y el mínimo/ máximo
        lower_err = mean - meas['min']
        upper_err = meas['max'] - mean
        ax.errorbar(
            x, mean, 
            yerr=[[lower_err], [upper_err]], 
            fmt='o', 
            color=colors[device],
            capsize=5,
            label=device if i == 0 else ""
        )

# Configuración del eje X para mostrar las categorías
ax.set_xticks(list(device_positions.values()))
ax.set_xticklabels(list(device_positions.keys()))
ax.set_ylabel('Tasa Media (MB/s)')
ax.set_title('Estadísticas de Transmisión por Medio de Conexión')
ax.legend()
ax.grid(True)

plt.show()
