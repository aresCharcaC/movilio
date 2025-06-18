# SOLUCIÓN: Separación de Servicios de Viajes

## Problema Original
Los usuarios pasajeros estaban obteniendo errores de autenticación al solicitar viajes porque el sistema estaba intentando refrescar tokens usando el endpoint de conductores (`/api/conductor-auth/refresh`) en lugar del endpoint correcto para usuarios (`/api/auth/refresh`).

## Causa Raíz
El `RideRemoteDataSource` original era usado tanto por pasajeros como por conductores, pero siempre intentaba refrescar tokens usando el endpoint de conductor, causando errores cuando usuarios pasajeros intentaban solicitar viajes.

## Solución Implementada

### 1. Creación de Servicios Separados

#### PassengerRideRemoteDataSource (SOLO PASAJEROS)
- **Archivo**: `lib/data/datasources/passenger_ride_remote_datasource.dart`
- **Funciones**:
  - `createRideRequest()` - Crear solicitud de viaje
  - `getRideRequest()` - Obtener detalles de viaje
  - `getActiveRideRequests()` - Obtener viajes activos
  - `cancelRideRequest()` - Cancelar viaje
  - `cancelAndDeleteActiveSearch()` - Cancelar búsqueda activa
  - `getRideOffers()` - Obtener ofertas de conductores
- **Token Refresh**: Usa `/api/auth/refresh` (endpoint de usuarios)
- **Sesión**: Integrado con `UserSessionService` para persistencia

#### DriverRideRemoteDataSource (SOLO CONDUCTORES)
- **Archivo**: `lib/data/datasources/driver_ride_remote_datasource.dart`
- **Funciones**:
  - `getNearbyRequests()` - Obtener solicitudes cercanas
  - `updateDriverLocation()` - Actualizar ubicación
  - `sendDriverOffer()` - Enviar oferta
  - `acceptRide()` - Aceptar viaje
  - `startRide()` - Iniciar viaje
  - `endRide()` - Finalizar viaje
- **Token Refresh**: Usa `/api/conductor-auth/refresh` (endpoint de conductores)
- **Sesión**: Sin persistencia local (solo cookies)

### 2. Actualización del Repositorio
- **Archivo**: `lib/data/repositories_impl/ride_repository_impl.dart`
- **Cambio**: Ahora usa `PassengerRideRemoteDataSource` en lugar de `RideRemoteDataSource`
- **Propósito**: Garantiza que las operaciones de pasajeros usen el servicio correcto

### 3. Actualización del Service Locator
- **Archivo**: `lib/core/di/service_locator.dart`
- **Cambios**:
  - Registra `PassengerRideRemoteDataSource` para pasajeros
  - Registra `DriverRideRemoteDataSource` para conductores
  - Mantiene `RideRemoteDataSource` como legacy por compatibilidad
  - Actualiza `RideRepository` para usar el servicio de pasajeros

## Beneficios de la Separación

### 🔒 Seguridad Mejorada
- Cada tipo de usuario usa su endpoint de autenticación correcto
- No hay confusión entre tokens de pasajeros y conductores
- Logs específicos para cada tipo de usuario

### 🎯 Responsabilidad Clara
- Servicios especializados para cada rol
- Funciones específicas para cada tipo de usuario
- Mantenimiento más fácil

### 🐛 Debugging Mejorado
- Logs etiquetados con `[PASAJERO]` o `[CONDUCTOR]`
- Errores más específicos y fáciles de rastrear
- Separación clara de responsabilidades

### 🔄 Manejo de Sesiones Diferenciado
- **Pasajeros**: Persistencia de sesión con `UserSessionService`
- **Conductores**: Solo cookies de sesión (sin persistencia local)

## Estructura Final

```
lib/data/datasources/
├── passenger_ride_remote_datasource.dart  # SOLO PASAJEROS
├── driver_ride_remote_datasource.dart     # SOLO CONDUCTORES
└── ride_remote_datasource.dart            # LEGACY (mantener por compatibilidad)

lib/data/repositories_impl/
└── ride_repository_impl.dart              # Usa PassengerRideRemoteDataSource

lib/core/di/
└── service_locator.dart                   # Registra ambos servicios separados
```

## Endpoints Utilizados

### Pasajeros (PassengerRideRemoteDataSource)
- **Autenticación**: `/api/auth/refresh`
- **Viajes**: `/api/rides/*`
- **Sesión**: Persistente con `UserSessionService`

### Conductores (DriverRideRemoteDataSource)
- **Autenticación**: `/api/conductor-auth/refresh`
- **Viajes**: `/api/rides/driver/*`
- **Sesión**: Solo cookies (sin persistencia)

## Resultado
✅ Los usuarios pasajeros ahora pueden solicitar viajes sin errores de autenticación
✅ Los conductores mantienen su funcionalidad separada
✅ No hay más confusión entre tipos de usuarios
✅ Sistema más robusto y mantenible

## Notas Importantes
- El `RideRemoteDataSource` original se mantiene como legacy por compatibilidad
- Todos los logs incluyen etiquetas `[PASAJERO]` o `[CONDUCTOR]` para facilitar debugging
- La separación es completa: nunca más se mezclarán los servicios de pasajeros y conductores
