# Pull Request #1 — `feature/login` → `develop`

**Autor:** Estudiante · **Revisor:** Estudiante (auto-revisión documentada)
**Estado:** Aprobado y fusionado con merge commit (`--no-ff`)

## Descripción

Implementa la autenticación del MVP con Supabase Auth:

- `Validators` (correo, contraseña, monto, descripción, nota) con pruebas unitarias.
- `SecureLocalStorage`: los tokens de sesión se guardan en Keychain / EncryptedSharedPreferences.
- `AuthService` y `AuthProvider` con estados `idle/loading/success/error`.
- Bloqueo de 30 s tras 5 intentos fallidos de inicio de sesión.
- `LoginScreen` con modo registro y validación de formulario.

## Lista de revisión

| # | Punto revisado | Resultado | Comentario |
|---|----------------|-----------|------------|
| 1 | Los tokens no usan SharedPreferences | OK | `SecureLocalStorage` sobrescribe el almacén por defecto del SDK. |
| 2 | Mensajes de error no revelan si un correo existe | OK | Error genérico "Correo o contraseña incorrectos". |
| 3 | Credenciales fuera del repositorio | OK | Se leen con `--dart-define`; `.gitignore` excluye `.env`. |
| 4 | Contraseña validada solo en registro | OK | En login solo se exige no vacía para no filtrar la política. |
| 5 | Controladores liberados en `dispose` | OK | `_emailCtrl` y `_passCtrl`. |
| 6 | Estados de carga y error visibles | OK | Botón con spinner y banner de error. |
| 7 | Pruebas unitarias de validadores | OK | `test/validators_test.dart`. |

## Observaciones (no bloqueantes)

1. `Validators.amount` solo comprueba `> 0`; conviene acotar el rango y los decimales.
   Se resolverá cuando exista el formulario de gastos (o como hotfix si llega a `main`).
2. El bloqueo por intentos fallidos vive en memoria: se reinicia al cerrar la app.
   Aceptable para el MVP, ya que Supabase aplica su propio límite de tasa en el servidor.
3. Falta pantalla de recuperación de contraseña (fuera de alcance del MVP).

## Decisión

Aprobado. Sin cambios solicitados. Se fusiona en `develop`.
