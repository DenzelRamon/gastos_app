# Gastos App

MVP de gestión de gastos personales hecho con **Flutter** y **Supabase**.
Registra gastos con foto del ticket, controla presupuestos semanales/mensuales, recibe alertas
locales al llegar al 80 % y sincroniza tus datos con la nube.

## Funcionalidades

| Requisito | Implementación |
|-----------|----------------|
| Persistencia local | SQLite (`sqflite`), esquema relacional con llaves foráneas |
| CRUD de gastos | Crear, listar, editar y eliminar (deslizar) |
| Modelo con 3 entidades | `Categoría` 1—N `Gasto`, `Categoría` 1—N `Presupuesto` |
| Autenticación | Supabase Auth (correo y contraseña) |
| Sincronización | API REST de Supabase (push/pull, *last-write-wins*) |
| Estados de carga y error | `ViewState` en login, lista de gastos y sincronización |
| Recurso multimedia | Cámara para fotografiar tickets (`image_picker`) |
| Notificaciones | Alerta local al 80 % y 100 % del presupuesto + recordatorio semanal programado |
| Seguridad | AES-256-GCM, tokens en almacén seguro, validación de entradas, RLS |
| Librerías de terceros | `intl`, `fl_chart`, `image_picker` (además de `provider`, `encrypt`, etc.) |

## Requisitos

- Flutter 3.27 o superior (Dart 3.3+)
- Un proyecto gratuito de [Supabase](https://supabase.com)
- Dispositivo o emulador Android / iOS (la cámara real requiere dispositivo físico)

## Instalación

### 1. Clonar y generar las carpetas de plataforma

El repositorio contiene el código Dart; las carpetas `android/` e `ios/` se generan con Flutter:

```bash
git clone https://github.com/DenzelRamon/gastos_app.git
cd gastos_app
flutter create . --platforms=android,ios --project-name gastos_app
flutter pub get
```

### 2. Configurar Supabase

1. Crea un proyecto en Supabase.
2. Abre **SQL Editor** y ejecuta el contenido de [`supabase/schema.sql`](supabase/schema.sql)
   (crea las tablas y activa Row Level Security).
3. En **Authentication → Providers** deja habilitado *Email*. Para probar más rápido puedes
   desactivar *Confirm email*.
4. Copia la **Project URL** y la **anon key** desde *Project Settings → API*.

### 3. Permisos de plataforma

**Android** — `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Y dentro de `<application>`:

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
  </intent-filter>
</receiver>
```

`flutter_local_notifications` requiere *core library desugaring*. En `android/app/build.gradle(.kts)`:

```gradle
compileOptions { coreLibraryDesugaringEnabled true }
dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4' }
```

Además, `minSdkVersion` debe ser **23** o superior (`flutter_secure_storage`).

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Se usa la cámara para fotografiar tus tickets de compra.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Se usa la galería para adjuntar fotos de tickets.</string>
```

### 4. Ejecutar

Las credenciales se pasan en tiempo de compilación; **nunca** se escriben en el código:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

Tip: guárdalas en un archivo `dart_defines.json` (ya está en `.gitignore`) y usa
`flutter run --dart-define-from-file=dart_defines.json`.

### 5. Pruebas

```bash
flutter test
flutter analyze
```

## Estructura

```
lib/
├── main.dart, app.dart        Arranque, tema, AuthGate
├── core/                      config, validators, crypto_service, secure_store, period, formatters
├── models/                    Category, Expense, Budget
├── data/                      DatabaseHelper + repositorios (CRUD, soft delete)
├── services/                  auth, sync, notificaciones, alertas de presupuesto, tickets
├── providers/                 AuthProvider, ExpenseProvider, SyncProvider (ChangeNotifier)
└── screens/                   login, home, lista/formulario de gastos, presupuestos, estadísticas
supabase/schema.sql            Tablas remotas + políticas RLS
docs/                          Revisión del PR #1 y reporte técnico
```

## Seguridad

- **Cifrado local:** notas y fotos de tickets se cifran con AES-256-GCM. La llave de 256 bits
  vive en Keychain/Keystore, nunca junto a los datos.
- **Tokens:** la sesión de Supabase se guarda en almacén seguro (`SecureLocalStorage`), no en
  SharedPreferences.
- **Validación:** todo input pasa por `Validators` (correo, contraseña fuerte, monto con
  rango y decimales acotados, longitudes) y `CHECK` en SQLite y Postgres.
- **Aislamiento:** una base SQLite por usuario y RLS en el servidor (`auth.uid() = user_id`).
- **Privacidad:** notas y tickets no se sincronizan; solo viajan monto, descripción, fecha y categoría.
- **Autenticación:** mensajes de error genéricos y bloqueo de 30 s tras 5 intentos fallidos.
- **Secretos:** credenciales por `--dart-define`; `.gitignore` excluye `.env` y `dart_defines.json`.

## Flujo de trabajo Git

- `main`: versiones estables (etiquetas `v1.0.0`, `v1.0.1`).
- `develop`: integración.
- `feature/login`, `feature/expenses-crud`, `feature/budget-notifications`, `feature/app-shell`.
- `hotfix/amount-validation`: corrección urgente sobre `main`.
- Pull Request de `feature/login` → `develop` con revisión documentada en
  [`docs/PR-1-feature-login.md`](docs/PR-1-feature-login.md).
- Pasos para publicar el historial en GitHub: [`docs/GITHUB.md`](docs/GITHUB.md).

## Limitaciones conocidas del MVP

- La llave de cifrado es **por dispositivo**: notas y tickets no se recuperan en otro teléfono.
- Resolución de conflictos *last-write-wins* con reloj del cliente.
- No hay recuperación de contraseña ni OCR (ML Kit queda como mejora opcional).
- Las categorías por defecto no se editan desde la interfaz (el repositorio ya soporta el CRUD).
