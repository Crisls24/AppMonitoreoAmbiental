# App de Monitoreo Ambiental de Invernaderos

Aplicación Flutter para el **monitoreo y control ambiental de invernaderos** en tiempo
real: temperatura, humedad y luminosidad de los sensores conectados, con automatización
de riego y gestión de cultivos desde una interfaz intuitiva.

## Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Firebase — Realtime Database (sensores), Cloud Firestore (usuarios e
  invernaderos) y Firebase Auth.
- **Autenticación:** email/contraseña y **Google Sign-In**.
- **Dependencias:** `firebase_core`, `firebase_auth`, `cloud_firestore`,
  `firebase_database`, `google_sign_in`, `fl_chart` (gráficas).

## Funcionalidades

- Registro e inicio de sesión con verificación de email y roles
  (dueño / empleado / pendiente).
- **Dashboard en vivo** con gráficas de temperatura, humedad y luminosidad,
  suscrito a la ruta `sensores/data` de Realtime Database.
- Carrusel de cultivos (lechuga, pepino, jitomate) con estados.
- **Gestión de invernaderos**: CRUD en Firestore, colaboradores e invitaciones por
  código o enlace compartido.
- Integrado con el ecosistema BioSensor (gateway + nodos ESP32 LoRa que publican
  los datos de sensores).

## Configuración Firebase

El proyecto ya incluye su configuración de Firebase para Android:

- `android/app/google-services.json`
- `lib/firebase_options.dart`
- Proyecto: `biosensor-55a96`

## Cómo ejecutar

```sh
flutter pub get
flutter run
```

> **Aviso:** la rama actual tiene pantallas referenciadas aún en desarrollo
> (`SeleccionRol`, `RegistroInvernadero`); el flujo completo requiere completar
> esos módulos.

## Soporte

Android / iOS. Para iOS se necesita agregar el `GoogleService-Info.plist` del
proyecto Firebase.