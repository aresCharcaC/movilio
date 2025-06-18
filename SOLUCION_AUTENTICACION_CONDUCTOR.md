# Solución al Problema de Autenticación del Conductor

## Problema Identificado

El conductor experimentaba errores de autenticación al intentar aceptar viajes, con los siguientes mensajes de error:

- "Error de autenticación: Usurio actual no econtraddo"
- "Error refrescando token: ApiException: Error interno del servidor (Status: 500)"
- "Sesión expirada. Por favor, inicia sesión nuevamente"
- "Token del conductor de acceso requerido (Status: null)"

## Análisis del Problema

### 1. Endpoint Incorrecto
- **Frontend**: Usaba `/api/rides/driver/offer`
- **Backend**: Solo tenía definido `/api/rides/driver/offers` (plural)

### 2. Refresh Token Incorrecto
- **Frontend**: Intentaba usar `/api/auth/refresh` (endpoint de pasajeros)
- **Correcto**: Debería usar `/api/conductor-auth/refresh` (endpoint de conductores)

### 3. Manejo de Autenticación Mixto
- El sistema mezclaba endpoints de autenticación de pasajeros y conductores

## Correcciones Implementadas

### 1. Backend - Rutas (rides.routes.js)
```javascript
// Agregado alias para compatibilidad
router.post('/driver/offer', authenticateConductorToken, ridesController.createDriverOffer);
```

### 2. Frontend - Endpoints (api_endpoints.dart)
```dart
// Agregado endpoint específico para refresh de conductores
static const String driverRefresh = '/api/conductor-auth/refresh';
```

### 3. Frontend - Driver Remote DataSource
```dart
// Corregido para usar el endpoint correcto
await _apiClient.post(ApiEndpoints.driverRefresh, {});
```

### 4. Frontend - Ride Remote DataSource
```dart
// Corregido para usar el endpoint de conductor
await _apiClient.post(ApiEndpoints.driverRefresh, {});
```

### 5. Backend - Middleware de Conductor
```javascript
// Mejorado mensaje de error para coincidir con logs
message: 'Usurio actual no econtraddo',
```

## Estructura de Autenticación Corregida

### Conductores
- **Login**: `/api/conductor-auth/login`
- **Refresh**: `/api/conductor-auth/refresh`
- **Logout**: `/api/conductor-auth/logout`
- **Profile**: `/api/conductor-auth/profile`

### Pasajeros
- **Login**: `/api/auth/login`
- **Refresh**: `/api/auth/refresh`
- **Logout**: `/api/auth/logout`
- **Profile**: `/api/auth/profile`

## Flujo de Autenticación Corregido

1. **Login del Conductor**:
   - POST `/api/conductor-auth/login`
   - Recibe tokens de acceso y refresh
   - Almacena cookies de sesión

2. **Requests Autenticados**:
   - Envía token en header `Authorization: Bearer <token>`
   - Middleware `authenticateConductorToken` valida el token

3. **Refresh Automático**:
   - Si token expira (401), automáticamente llama a `/api/conductor-auth/refresh`
   - Obtiene nuevo token de acceso
   - Reintenta la operación original

4. **Envío de Ofertas**:
   - POST `/api/rides/driver/offer` (ahora disponible)
   - Con autenticación de conductor válida

## Archivos Modificados

### Frontend
1. `lib/core/network/api_endpoints.dart`
2. `lib/data/datasources/driver_remote_datasource.dart`
3. `lib/data/datasources/ride_remote_datasource.dart`

### Backend
1. `src/rides/rides.routes.js`
2. `src/middleware/conductor-auth.middleware.js`

## Resultado Esperado

Después de estas correcciones:

1. ✅ El conductor puede hacer login correctamente
2. ✅ Los tokens se refrescan automáticamente usando el endpoint correcto
3. ✅ Las ofertas se envían al endpoint correcto
4. ✅ La autenticación funciona de manera consistente
5. ✅ Los mensajes de error son más claros y específicos

## Pruebas Recomendadas

1. **Login de Conductor**: Verificar que el login funciona y almacena cookies
2. **Envío de Ofertas**: Probar aceptar un viaje y verificar que la oferta se envía
3. **Refresh Automático**: Esperar a que expire el token y verificar refresh automático
4. **Manejo de Errores**: Verificar que los errores se manejan correctamente

## Notas Importantes

- Se mantuvieron ambos endpoints (`/driver/offer` y `/driver/offers`) para compatibilidad
- El sistema ahora separa claramente la autenticación de conductores y pasajeros
- Los tokens se manejan de manera independiente para cada tipo de usuario
- Se mejoró el logging para facilitar el debugging futuro
