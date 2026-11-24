# Publicar el historial en GitHub

El repositorio ya trae el historial completo (ramas, merges y etiquetas). Para que el
**Pull Request #1** exista como objeto real en GitHub (con su revisión), publica en este orden.

## 1. Crear el repositorio vacío

En GitHub: **New repository** → público, sin README ni `.gitignore` (ya vienen en el proyecto).

```bash
git remote add origin https://github.com/TU-USUARIO/gastos_app.git
```

## 2. Publicar `main`, `develop` previo al PR y `feature/login`

La etiqueta local `pre-pr-login` marca `develop` justo antes de fusionar `feature/login`.

```bash
git push origin main
git push origin pre-pr-login:refs/heads/develop
git push origin feature/login
```

## 3. Abrir el Pull Request y documentar la revisión

1. En GitHub: **Compare & pull request** de `feature/login` hacia `develop`.
2. Pega el contenido de [`PR-1-feature-login.md`](PR-1-feature-login.md) como descripción.
3. En la pestaña **Files changed** deja los comentarios de la revisión
   (GitHub no permite aprobar tu propio PR; usa **Comment** y cita la lista de revisión).
4. Toma capturas de pantalla para el reporte si tu profesor las pide.

## 4. Publicar el resto del historial

Al subir `develop` completo (que ya contiene el merge de `feature/login`), GitHub marcará el
PR #1 automáticamente como **Merged**:

```bash
git push origin develop
git push origin --tags
git push origin feature/expenses-crud feature/budget-notifications feature/app-shell hotfix/amount-validation
```

## 5. Verificar los requisitos

```bash
git rev-list --count main          # commits en main (>= 15 en total en el repo)
git branch -a                      # main, develop, feature/*, hotfix/*
git log --oneline --graph --all    # historial con merges
```

## Autoría de los commits

Los commits se crearon con el autor genérico `Estudiante <estudiante@example.com>`.
Para que aparezcan con tu cuenta de GitHub, reescribe la autoría **antes** de publicar:

```bash
git filter-branch -f --env-filter '
export GIT_AUTHOR_NAME="Tu Nombre";   export GIT_COMMITTER_NAME="Tu Nombre"
export GIT_AUTHOR_EMAIL="tu@correo.com"; export GIT_COMMITTER_EMAIL="tu@correo.com"
' --tag-name-filter cat -- --branches --tags
```
