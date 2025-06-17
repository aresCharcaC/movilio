# Solución: Problemas con Solicitudes del Conductor

## 🐛 Problemas Identificados

### 1. Filtrado Incorrecto por Distancia
- **Problema**: Las solicitudes se filtraban incorrectamente mostrando "8035157m muy lejos"
- **Causa**: Error en el cálculo de distancia y uso de datos incorrectos del WebSocket
- **Síntoma**: Solicitudes cercanas aparecían como "muy lejos" y se filtraban

### 2. Tarjetas Vacías en la UI
- **Problema**: Las tarjetas de solicitudes aparecían sin datos (sin nombre, sin dirección, sin destino)
- **Causa**: Mapeo incorrecto de los campos de datos del WebSocket al formato esperado por el widget
- **Síntoma**: Cards mostraban "Sin nombre", "Dirección no especificada", etc.

### 3. Estructura de Datos Inconsistente
- **Problema**: Los datos del WebSocket tenían una estructura diferente a la esperada por el frontend
- **Causa**: Falta de modelo específico para manejar datos de solicitudes cercanas del conductor
- **Síntoma**: Errores de parsing y datos faltantes

## ✅ Soluciones Implementadas

### 1. Nuevo Modelo de Datos: `DriverNearbyRequestModel`

**Archivo**: `lib/data/models/driver_nearby_request_model.dart`

- **Propósito**: Modelo específico para manejar solicitudes cercanas del conductor
- **Características**:
  - Parsing robusto de datos del WebSocket
  - Mapeo completo de todos los campos necesarios
  - Conversión a formato compatible con widgets existentes
  - Manejo seguro de tipos de datos

**Campos principales**:
```dart
- viajeId: String
- usuarioNombre: String  
- usuarioFoto: String?
- usuarioRating: double
- origenDireccion: String
- destinoDireccion: String
- origenLat/Lng: double
- destinoLat/Lng: double
- distanciaConductor: double  // ⭐ Clave para filtrado
- precioUsuario: double
- metodosPago: List<String>
- fechaSolicitud: DateTime
```

### 2. Actualización del ViewModel del Conductor

**Archivo**: `lib/presentation/modules/auth/Driver/viewmodels/driver_home_viewmodel.dart`

**Cambios principales**:

#### A. Nuevo Método de Parsing
```dart
// Usar el nuevo modelo para parsear datos del WebSocket
final nearbyRequest = DriverNearbyRequestModel.fromWebSocketData(
  requestData as Map<String, dynamic>,
);

// Convertir al formato esperado por el widget
final solicitudFormateada = nearbyRequest.toDisplayFormat();
```

#### B. Filtrado Mejorado por Distancia
```dart
// Usar la distancia ya calculada por el backend
final distanciaConductor = solicitud['distanciaConductor'] ?? 
                          solicitud['distancia_conductor'] ?? 
                          double.infinity;

final dentroDelRadio = distanciaConductor <= maxDistanceKm;
```

#### C. Fallback Robusto
```dart
// Si el nuevo modelo falla, usar el método anterior
try {
  // Nuevo método
} catch (e) {
  // Método fallback
}
```

### 3. Mejoras en el Widget de Lista

**Archivo**: `lib/presentation/modules/auth/Driver/widgets/driver_request_list.dart`

**Cambios**:

#### A. Mapeo Extendido de Precios
```dart
final precio = _getDoubleProperty(request, [
  'precioUsuario',      // ⭐ Nuevo
  'precio_usuario',     // ⭐ Nuevo  
  'precio',
  'tarifaMaxima',
  'tarifa_maxima',
  'tarifa_referencial', // ⭐ Nuevo
  'precioSugerido',     // ⭐ Nuevo
  'precio_sugerido',    // ⭐ Nuevo
]) ?? 0.0;
```

#### B. Validación Mejorada de Datos
```dart
// Verificar que el valor no sea null ni cadena vacía
if (value != null && value.toString().trim().isNotEmpty) {
  return value;
}
```

## 🔧 Estructura de Datos del WebSocket

### Formato Recibido del Backend:
```json
{
  "nearby_requests": [
    {
      "viaje_id": "13304693-b817-40ec-b14f-c317eb5d1bf8",
      "usuario": {
        "id": "1b7dac8b-090f-4450-b930-216a1c70eab7",
        "nombre": "Fedeo X Tu Bien",
        "telefono": "+51974335599",
        "foto": "https://images.icon-icons.com/...",
        "rating": 0.00
      },
      "origen": {
        "lat": -16.40791000,
        "lng": -71.48216000,
        "direccion": "Calle Jesus"
      },
      "destino": {
        "lat": -16.39664000,
        "lng": -71.53669000,
        "direccion": "Calle Santa Catalina 204"
      },
      "distancia_km": 5.95,
      "distancia_conductor": 0.005016888596439851, // ⭐ Clave
      "tiempo_llegada_estimado": 1,
      "precio_usuario": 10.50,
      "precio_sugerido_app": 10.64,
      "metodos_pago": [],
      "fecha_solicitud": "2025-06-17T02:49:38.510Z",
      "ya_oferté": false,
      "total_ofertas": 0
    }
  ],
  "count": 1
}
```

### Formato Convertido para el Widget:
```json
{
  "id": "13304693-b817-40ec-b14f-c317eb5d1bf8",
  "nombre": "Fedeo X Tu Bien",
  "usuarioNombre": "Fedeo X Tu Bien",
  "foto": "https://images.icon-icons.com/...",
  "direccion": "Calle Jesus",
  "origenDireccion": "Calle Jesus",
  "destinoDireccion": "Calle Santa Catalina 204",
  "precio": 10.50,
  "precioUsuario": 10.50,
  "distanciaConductor": 0.005016888596439851,
  "metodos": [],
  "rating": 0.0,
  // ... más campos para compatibilidad
}
```

## 🧪 Cómo Probar la Solución

### 1. Verificar Logs de Debug
Buscar en los logs estos mensajes:
```
✅ Solicitud parseada: DriverNearbyRequestModel(...)
✅ Solicitud dentro del radio - 5m
🔍 Filtrado: 1 de 1 solicitudes mostradas (radio: 5.0km)
```

### 2. Verificar UI
- Las tarjetas deben mostrar:
  - ✅ Nombre del usuario
  - ✅ Dirección de origen
  - ✅ Dirección de destino  
  - ✅ Precio correcto
  - ✅ Métodos de pago (si están disponibles)

### 3. Verificar Filtrado
- Solicitudes cercanas (< 5km) deben aparecer
- Solicitudes lejanas deben filtrarse con mensaje claro
- No debe aparecer "8035157m muy lejos"

## 🔍 Debugging

### Logs Importantes a Monitorear:

1. **Parsing exitoso**:
   ```
   ✅ Solicitud parseada: DriverNearbyRequestModel(viajeId: xxx, usuario: xxx, ...)
   ```

2. **Filtrado correcto**:
   ```
   ✅ Solicitud xxx dentro del radio - 5m
   ```

3. **Fallback activado** (si hay problemas):
   ```
   ⚠️ Error formateando solicitud: ...
   ✅ Solicitud parseada con método fallback
   ```

4. **Error total** (requiere investigación):
   ```
   ❌ Error también en método fallback: ...
   ```

## 📋 Checklist de Verificación

- [ ] Las solicitudes aparecen en las tarjetas con datos completos
- [ ] El filtrado por distancia funciona correctamente
- [ ] No aparecen mensajes de "8035157m muy lejos"
- [ ] Los precios se muestran correctamente
- [ ] Las direcciones de origen y destino son visibles
- [ ] Los nombres de usuarios aparecen
- [ ] Los logs muestran parsing exitoso

## 🚀 Próximos Pasos

1. **Monitorear** el comportamiento en producción
2. **Ajustar** el radio de búsqueda si es necesario
3. **Optimizar** el parsing si se encuentran nuevos casos edge
4. **Agregar** más validaciones si se detectan problemas adicionales

## 📝 Notas Técnicas

- El campo `distancia_conductor` viene en **kilómetros** desde el backend
- El filtrado se hace usando este valor pre-calculado en lugar de calcular en el frontend
- Se mantiene compatibilidad con el formato anterior como fallback
- El nuevo modelo es extensible para futuros campos adicionales
